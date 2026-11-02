const editor = getEditor();

// Lazygit: one terminal per repository, reused while it runs.
const lazygitByCwd: Record<string, { terminalId: number; bufferId: number; splitId: number | null }> = {};

async function openLazygit(repo: string): Promise<void> {
  const open = lazygitByCwd[repo];
  if (open && open.splitId !== null) {
    editor.focusSplit(open.splitId);
    return;
  }
  try {
    const term = await editor.createTerminal({
      cwd: repo,
      command: ["lazygit"],
      title: "lazygit " + editor.pathBasename(repo),
      direction: "vertical",
      ratio: 0.5,
      focus: true,
    });
    lazygitByCwd[repo] = { terminalId: term.terminalId, bufferId: term.bufferId, splitId: term.splitId };
  } catch (e) {
    editor.setStatus("Lazygit: " + e);
  }
}

// Repository of the active file, falls back to the editor cwd for a non-file buffer or a file
// outside any repository. The file explorer previews the selected file into the editor pane, so
// this also follows the explorer selection (files only, the API does not expose a selected directory).
async function activeRepo(): Promise<string> {
  const path = editor.getBufferPath(editor.getActiveBufferId());
  if (!path) return editor.getCwd();
  const res = await editor.spawnProcess("git", ["rev-parse", "--show-toplevel"], editor.pathDirname(path));
  return res.exit_code === 0 ? res.stdout.trim() : editor.getCwd();
}

registerHandler("lazygit_open", async function () {
  await openLazygit(await activeRepo());
});

// Pick any repository under the cwd, e.g. the separate packages cloned into ros2_ws/src
let lazygitRepos: string[] = [];

function showLazygitRepos(filter: string): void {
  const cwd = editor.getCwd();
  const f = filter.toLowerCase();
  editor.setPromptSuggestions(
    lazygitRepos
      .filter((r) => r.toLowerCase().includes(f))
      .map((r) => ({ id: r, text: r === cwd ? "." : r.slice(cwd.length + 1), value: r, description: lazygitByCwd[r] ? "open" : undefined })),
  );
}

registerHandler("lazygit_pick", async function () {
  const cwd = editor.getCwd();
  // Build outputs and worktrees hold no repositories worth picking and are slow to walk
  const res = await editor.spawnProcess("find", [
    cwd, "-maxdepth", "6",
    "(", "-name", "build", "-o", "-name", "install", "-o", "-name", "log", "-o", "-name", "node_modules", "-o", "-name", ".claude", ")", "-prune",
    "-o", "-name", ".git", "-print",
  ]);
  lazygitRepos = res.stdout.split("\n").filter((l) => l).map((l) => editor.pathDirname(l)).sort();
  if (lazygitRepos.length === 0) {
    editor.setStatus("Lazygit: no repository under " + cwd);
    return;
  }
  editor.startPrompt("Lazygit repo: ", "lazygit-pick");
  showLazygitRepos("");
});

registerHandler("lazygit_pick_changed", function (args: { prompt_type: string; input: string }) {
  if (args.prompt_type === "lazygit-pick") showLazygitRepos(args.input);
});

registerHandler("lazygit_pick_confirmed", async function (args: { prompt_type: string; input: string }) {
  if (args.prompt_type !== "lazygit-pick") return false;
  if (lazygitRepos.includes(args.input)) await openLazygit(args.input);
  return true;
});

editor.on("prompt_changed", "lazygit_pick_changed");
editor.on("prompt_confirmed", "lazygit_pick_confirmed");

registerHandler("lazygit_on_exit", function (ev: { terminal_id: number }) {
  for (const cwd of Object.keys(lazygitByCwd)) {
    const t = lazygitByCwd[cwd];
    if (t.terminalId !== ev.terminal_id) continue;
    delete lazygitByCwd[cwd];
    editor.closeBuffer(t.bufferId, true);
    if (t.splitId !== null) editor.closeSplit(t.splitId);
  }
});

editor.registerCommand("Lazygit", "Open lazygit for the repository of the current file in a split", "lazygit_open", null);
editor.registerCommand("Lazygit: Pick Repository", "Open lazygit for a repository under the working directory", "lazygit_pick", null);
editor.on("terminal_exit", "lazygit_on_exit");

// Window navigation: focus the nearest pane in a direction, by on-screen geometry.
function focusPaneInDirection(dir: "left" | "right" | "up" | "down"): void {
  const ws = editor.describeWorkspace();
  const cur = ws.panes.find((p) => p.splitId === ws.activeSplitId);
  if (!cur) return;
  let best: { splitId: number; dist: number; overlap: number } | null = null;
  for (const p of ws.panes) {
    if (p.splitId === cur.splitId) continue;
    const horizontal = dir === "left" || dir === "right";
    const dist =
      dir === "left" ? cur.x - (p.x + p.width) :
      dir === "right" ? p.x - (cur.x + cur.width) :
      dir === "up" ? cur.y - (p.y + p.height) :
      p.y - (cur.y + cur.height);
    // Panes are separated by a 1-cell divider, anything behind the current pane is negative
    if (dist < 0) continue;
    const overlap = horizontal
      ? Math.min(cur.y + cur.height, p.y + p.height) - Math.max(cur.y, p.y)
      : Math.min(cur.x + cur.width, p.x + p.width) - Math.max(cur.x, p.x);
    if (overlap <= 0) continue;
    if (!best || dist < best.dist || (dist === best.dist && overlap > best.overlap)) {
      best = { splitId: p.splitId, dist, overlap };
    }
  }
  if (best) editor.focusSplit(best.splitId);
}

registerHandler("win_focus_left", () => focusPaneInDirection("left"));
registerHandler("win_focus_right", () => focusPaneInDirection("right"));
registerHandler("win_focus_up", () => focusPaneInDirection("up"));
registerHandler("win_focus_down", () => focusPaneInDirection("down"));

// Vi ex commands: `:q`, `:wq` and `:x` close only the current tab instead of quitting the editor.
// The vi plugin offers no hook for its ex commands, so `:` opens this prompt and hands every
// other command over to the vi prompt.
registerHandler("ex_prompt", function () {
  editor.startPrompt(":", "ex-wrap");
});

registerHandler("ex_prompt_confirmed", async function (args: { prompt_type: string; input: string }) {
  if (args.prompt_type !== "ex-wrap") return false;
  const input = args.input.trim();
  if (!input) return true;

  const m = input.match(/^(q|quit|clo|close|wq|x|xit)(!)?$/);
  if (!m) {
    editor.startPromptWithInitial(":", "vi-command", input);
    await editor.flush();
    editor.executeAction("prompt_confirm");
    return true;
  }

  const save = m[1] === "wq" || m[1] === "x" || m[1] === "xit";
  const force = m[2] === "!";
  const bufferId = editor.getActiveBufferId();
  if (save) {
    if (!editor.getBufferPath(bufferId)) {
      editor.setStatus("E: No file name");
      return true;
    }
    editor.executeAction("save");
    await editor.flush();
  } else if (!force && editor.isBufferModified(bufferId)) {
    editor.setStatus(`E: No write since last change (add ! to override)`);
    return true;
  }
  if (force) {
    editor.closeBuffer(bufferId, true);
  } else {
    editor.executeAction("close");
  }
  return true;
});

editor.on("prompt_confirmed", "ex_prompt_confirmed");

editor.registerCommand("Window: Focus Left", "Focus the pane to the left", "win_focus_left", null);
editor.registerCommand("Window: Focus Right", "Focus the pane to the right", "win_focus_right", null);
editor.registerCommand("Window: Focus Up", "Focus the pane above", "win_focus_up", null);
editor.registerCommand("Window: Focus Down", "Focus the pane below", "win_focus_down", null);
// Keybindings reach a plugin handler only through a registered command
editor.registerCommand("Vi: Ex Command", "Open the vi : prompt (:q closes only the current tab)", "ex_prompt", null);

// Hide the focused pane (e.g. the Claude terminal) by maximizing another one, and bring it back.
let hiddenPaneSplitId: number | null = null;

registerHandler("pane_hide_toggle", async function () {
  const ws = editor.describeWorkspace();
  if (hiddenPaneSplitId !== null && ws.panes.length === 1) {
    editor.executeAction("toggle_maximize_split");
    await editor.flush();
    editor.focusSplit(hiddenPaneSplitId);
    hiddenPaneSplitId = null;
    return;
  }
  const other = ws.panes.find((p) => p.splitId !== ws.activeSplitId);
  if (!other) return;
  hiddenPaneSplitId = ws.activeSplitId;
  editor.focusSplit(other.splitId);
  await editor.flush();
  editor.executeAction("toggle_maximize_split");
});

editor.registerCommand("Window: Hide/Show Current Pane", "Maximize another pane to hide the focused one, again to restore it", "pane_hide_toggle", null);

// File explorer: open the selected file in a new split (vim/nvim-tree <C-v> / <C-x>).
// The explorer offers no "open in split" action, so open the file normally and move its tab
// into a new split. The explorer keeps the keyboard when the selection is a directory.
let chromeRegion = "editor";
// What the editor pane showed before the explorer started previewing files into it
let bufferBeforeExplorer: number | null = null;
registerHandler("track_chrome_focus", function (ev: { region: string }) {
  if (ev.region === "explorer" && chromeRegion !== "explorer") bufferBeforeExplorer = editor.getActiveBufferId();
  chromeRegion = ev.region;
});
editor.on("chrome_focus_changed", "track_chrome_focus");

async function explorerOpenInSplit(direction: "vertical" | "horizontal"): Promise<void> {
  editor.executeAction("file_explorer_open");
  await editor.flush();
  // Opening a file hands the keyboard to the editor, the focus event arrives a moment later
  for (let i = 0; i < 10 && chromeRegion === "explorer"; i++) await editor.delay(30);
  if (chromeRegion === "explorer") return;
  // The new split starts with the opened file; drop its tab from the original split so that
  // one shows what it showed before the explorer previewed the file into it
  const originalSplitId = editor.getActiveSplitId();
  const split = await editor.splitWindow({ direction });
  editor.focusSplit(originalSplitId);
  editor.executeAction("close_tab");
  await editor.flush();
  if (bufferBeforeExplorer !== null && editor.listBuffers().some((b) => b.id === bufferBeforeExplorer)) {
    editor.setSplitBuffer(originalSplitId, bufferBeforeExplorer);
  }
  editor.focusSplit(split.splitId);
}

registerHandler("explorer_open_vsplit", () => explorerOpenInSplit("vertical"));
registerHandler("explorer_open_hsplit", () => explorerOpenInSplit("horizontal"));
editor.registerCommand("File Explorer: Open in Vertical Split", "Open the selected file in a split to the right", "explorer_open_vsplit", null);
editor.registerCommand("File Explorer: Open in Horizontal Split", "Open the selected file in a split below", "explorer_open_hsplit", null);

// Alt+i from a terminal pane: a global key bound to a built-in action does not fire there,
// one bound to a plugin action does
registerHandler("explorer_focus", function () {
  editor.executeAction("focus_file_explorer");
});
editor.registerCommand("File Explorer: Focus (from any pane)", "Move the keyboard to the file explorer, also from a terminal", "explorer_focus", null);
