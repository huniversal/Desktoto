"""update-source.html의 장면을 프레임으로 캡처해 GIF로 조립한다. 사용법은 build.sh를 참고한다.

Chrome(헤드리스)으로 시간 t마다 한 프레임을 캡처하고, Pillow로 모든 프레임이 같은 팔레트를 쓰게 줄여 GIF 한 장으로 묶는다.
같은 팔레트를 쓰면 프레임 사이의 깜빡임과 용량이 줄어든다.
"""
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageColor

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FPS = 10
WIDTH, HEIGHT = 720, 405
LAST_FRAME_HOLD_MS = 1800
LENGTHS = {"brew": 9.5, "dmg": 12.5}
KEY_COLORS = ["#e8825a", "#2f6fe0", "#2b2626", "#ff5f57", "#febc2e", "#28c840", "#dcdce0"]


def capture(source: Path, name: str, index: int, workdir: Path) -> Path:
    out = workdir / f"{name}-{index:04d}.png"
    if out.exists():  # FRAMES_DIR로 프레임을 남겨 두었다면 다시 캡처하지 않는다.
        return out
    profile = workdir / f"profile-{index % 4}"
    time = index / FPS
    subprocess.run(
        [
            CHROME, "--headless", "--hide-scrollbars", f"--user-data-dir={profile}",
            f"--window-size={WIDTH},{HEIGHT}", "--virtual-time-budget=500", f"--screenshot={out}",
            f"file://{source}#{name},t={time:.2f}",
        ],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    return out


def build(source: Path, name: str, destination: Path) -> None:
    count = int(LENGTHS[name] * FPS)
    keep = os.environ.get("FRAMES_DIR")
    with tempfile.TemporaryDirectory() as temp:
        workdir = Path(keep) if keep else Path(temp)
        workdir.mkdir(parents=True, exist_ok=True)
        # 같은 프로필을 동시에 쓰면 Chrome이 충돌하므로 프레임 번호를 4로 나눈 나머지별로 묶어 순서대로 캡처한다.
        groups = [[i for i in range(count) if i % 4 == lane] for lane in range(4)]

        def run_lane(indices):
            return [capture(source, name, i, workdir) for i in indices]

        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(run_lane, groups))
        paths = sorted(path for group in results for path in group)
        frames = [Image.open(path).convert("RGB").resize((WIDTH, HEIGHT)) for path in paths]

        # 모든 프레임을 절반 크기로 이어 붙여 공용 팔레트를 만든다. 일부 프레임에만 나오는 색(캐릭터, 버튼)도 팔레트에 남기 위해서다.
        half = (WIDTH // 2, HEIGHT // 2)
        sheet = Image.new("RGB", (half[0] * 5, half[1] * ((len(frames) + 4) // 5)))
        for number, frame in enumerate(frames):
            sheet.paste(frame.resize(half), (half[0] * (number % 5), half[1] * (number // 5)))
        # 중앙값 분할은 작게만 나오는 색(캐릭터)을 버릴 수 있어서, 240색만 계산하고 핵심 색 16칸은 직접 채운다.
        computed = sheet.quantize(colors=240, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).getpalette()[: 240 * 3]
        keys = [channel for color in KEY_COLORS for channel in ImageColor.getrgb(color)]
        palette = Image.new("P", (1, 1))
        palette.putpalette(computed + keys + [0] * (768 - len(computed) - len(keys)))
        # 디더링은 끈다. 배경 그라데이션이 단순해서 띠가 거의 보이지 않고, 켜면 용량이 크게 늘고 작은 색(캐릭터)이 점무늬가 된다.
        indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]

        durations = [1000 // FPS] * len(indexed)
        durations[-1] = LAST_FRAME_HOLD_MS
        indexed[0].save(
            destination, save_all=True, append_images=indexed[1:], duration=durations, loop=0, optimize=False, disposal=1
        )
    print(f"{destination}: {destination.stat().st_size // 1024} KB, {len(indexed)} frames")


if __name__ == "__main__":
    folder = Path(__file__).resolve().parent
    names = sys.argv[1:] or list(LENGTHS)
    for scene in names:
        build(folder / "update-source.html", scene, folder / f"update-{scene}.gif")
