const editor = getEditor();

// Lazygit: one terminal per working directory, reused while it runs.
const lazygitByCwd: Record<string, { terminalId: number; bufferId: number; splitId: number | null }> = {};

registerHandler("lazygit_open", async function () {
  const cwd = editor.getCwd();
  const open = lazygitByCwd[cwd];
  if (open && open.splitId !== null) {
    editor.focusSplit(open.splitId);
    return;
  }
  try {
    const term = await editor.createTerminal({
      cwd,
      command: ["lazygit"],
      title: "lazygit",
      direction: "vertical",
      ratio: 0.5,
      focus: true,
    });
    lazygitByCwd[cwd] = { terminalId: term.terminalId, bufferId: term.bufferId, splitId: term.splitId };
  } catch (e) {
    editor.setStatus("Lazygit: " + e);
  }
});

registerHandler("lazygit_on_exit", function (ev: { terminal_id: number }) {
  for (const cwd of Object.keys(lazygitByCwd)) {
    const t = lazygitByCwd[cwd];
    if (t.terminalId !== ev.terminal_id) continue;
    delete lazygitByCwd[cwd];
    editor.closeBuffer(t.bufferId, true);
    if (t.splitId !== null) editor.closeSplit(t.splitId);
  }
});

editor.registerCommand("Lazygit", "Open lazygit for the current project in a split", "lazygit_open", null);
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
