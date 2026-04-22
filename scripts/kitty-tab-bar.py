import os
import tempfile

# Persists last-active tab state across on_focus_change (watcher, cached) and
# draw_title ({custom} template, re-run each render via runpy.run_path).
# Format: "LAST_ID CURRENT_ID" where LAST_ID is 'none' until a second tab is visited.
_state = os.path.join(tempfile.gettempdir(), f'kitty-last-tab-{os.getuid()}')


def on_focus_change(boss, window, data):
    if not data.get('focused'):
        return
    new_id = window.tab_id
    try:
        with open(_state) as f:
            parts = f.read().strip().split()
        cur_id = int(parts[1])
    except Exception:
        cur_id = None
    if cur_id is None or cur_id == new_id:
        with open(_state, 'w') as f:
            f.write(f'none {new_id}')
        return
    with open(_state, 'w') as f:
        f.write(f'{cur_id} {new_id}')


def draw_title(data):
    tab_id = data.get('tab_id')
    title = data.get('title', '')
    try:
        with open(_state) as f:
            parts = f.read().strip().split()
        if parts[0] != 'none' and tab_id == int(parts[0]):
            return '\u00b7 ' + title
    except Exception:
        pass
    return title
