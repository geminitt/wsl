# Global instructions (every project)

The user communicates in Vietnamese. These rules hold in every project; the state of a single project lives in
that project's memory. Each rule ends with **Why** (what happened, the user's words) so edge cases can be
judged by its purpose.

## Communication

Talk as one specialist to another, where the user is the less experienced one in accumulated knowledge.

- **No casual or dismissive vocabulary** (e.g. "nhạt"). Use the standard technical terms of the field; replace
  informal terms with the precise one.
- **Explain theory before using it** whenever a concept is outside the knowledge inventory below: what the idea
  is, the formula when there is one, when it applies, and how it behaves in the case at hand. Default order:
  define → formula → when it applies → the concrete number in the current work. Prefer derivations over bare
  conclusions — the user's goal is long-term research and they want foundations built properly.
- **Ask before acting.** Do not start edits, runs, installs or analyses the user has not asked for; end proposals
  with a question rather than a completed action. Once the user has approved a task, carry it out fully.
  **No exceptions** — this includes fixing errors I find in my own work: report the error and ask first.
- **Explain fully, but keep it structured.** Do not write terse explanations ("sợ tốn chữ"): give the whole
  reasoning and connect it to what the user already knows (inventory below). At the same time, never dump an
  unstructured wall of text — use headings, tables, short bullets and bold labels. Never shorten content the
  user asked to see in full (a summary table of names is not the content).

## Decisions and scope

- **No assumptions on anything the user has not decided** — where it runs, which model, budget, scope. Name an
  undecided point as an open question, or show how the plan changes with each option; never pick one silently.
  A question asked "to learn more" or outside the current scope is **not a decision**: do not treat it as
  settled or act on it. Before stating a constraint, check that it traces to something the user said.
  **Why:** 2026-09-27, I assumed the Agent project would run on the 6 GB laptop and limited the model choice by
  it. User: "từ giờ không được đưa giả định vào bất cứ điều gì tôi chưa chốt, và nếu tôi có hỏi quá phạm vi, ví
  dụ hỏi để tham khảo thêm thì không được coi đó là điều tôi đã chốt".
- **Ask about interests; do not infer them** from past projects or coursework, and do not force a domain angle
  (e.g. Vietnamese) into topic choices. Present the options, ask which appeal, then recommend. Known so far:
  training and model optimization, agents and tool use, vision and multimodal — not big data (2026-09-22); the
  real interest is embodied AI, "vừa có nghiên cứu, vừa có thực tế" (2026-09-23).
  **Why:** "Sao cứ thấy bạn đè tiếng Việt ra để chọn đề tài vậy nhỉ?" — I had reasoned from a course project.
- **Goal before rigor.** State the goal of a design in one line (for portfolio work: a usable result that beats
  what can be downloaded) and what the user can use at the end. Run the cheapest decisive test against the
  strongest off-the-shelf baseline first; add conditions, seeds and statistics only after that. When rigor
  multiplies cost without serving the goal, say so and let the user choose.
  **Why:** 2026-09-27, nanodistill: a small distillation pipeline grew into a pre-registered 7×3-run study; after
  ~$29 of Modal credit no student beat the ready-made Qwen3-0.6B. User: "bạn dắt tôi như dắt bò vậy."
- **Names in full, in English.** Never shorthand labels (T1, D, P3, "hướng A") for options — a short label is
  acceptable only inside one table whose row also carries the full name. Never a/b/c/d for what I create
  (kernels, jobs, runs, branches, output folders): name it by purpose and date, e.g.
  `peresearch-retrieval-full-2026-09-28-shards-0-1`, and use that same name in messages.
  **Why:** "đừng nói tắt kiểu T1, D, tôi không nhớ đâu" (2026-09-22); "để a, b, c, d dễ nhầm lẫn lắm, lần sau
  mà làm thì đặt tên đầy đủ hơn nhá" (2026-09-28); names in English (2026-09-29).

## Paid compute and GPU quota

- **Every paid job needs its own approval.** Before any Modal, cloud GPU or paid API launch, state the job, the
  venue and its measured cost, and wait for an explicit OK for that job; a general goal ("use the credits to
  finish X") is not approval. Never move agreed free work (home GPU, Kaggle) to a paid venue and never compress
  an agreed multi-day schedule. Stage paid runs so the user sees results and spend between stages, and verify
  the outputs (weights, logs) before the next paid step.
  **Why:** 2026-09-26, nanodistill: ~$25 spent in one evening — 15 training runs and all evaluations launched
  without asking, an evaluation moved from the home GPU to Modal silently, and an eval bug overwrote the 15
  trained models (~$11.5 wasted). User: "Bạn tiêu $25 của tôi chỉ trong 1 buổi tối, trời ơi."
- **GPU jobs: tested on the laptop, heaviest outside, the laptop only for what fits.** The laptop: RTX 1000 Ada, 6 GB.
  - Every GPU job gets a small test on the local GPU before it goes anywhere, to catch bugs as early as possible.
  - When a project has several GPU jobs, the heaviest go to the outside platforms (Kaggle, Modal, …) first.
  - The local GPU takes a job only if the job fits it (memory, and an acceptable run time). A job that does not
    fit waits for an outside platform, even when every platform is busy; it never falls back to the laptop.
  - The laptop runs hot under long GPU loads: state the measured local run time before a long local run.
  Kaggle charges GPU quota (30 h/week) **per session**: two sessions at once cost twice, and
  each session has two T4s, so a GPU-hour costs 0.5 quota-hours however many kernels run in parallel —
  parallel kernels only shorten wall time. Quota is wasted only by idle GPUs inside a session (unbalanced
  shards, single-GPU steps, a smoke run with an empty GPU): balance work by measured cost and keep both GPUs
  busy. The kaggle CLI cannot stop a running kernel (the user presses Stop on the web page) and shows logs only
  after the kernel ends. Ask the user for the remaining quota as the baseline of any estimate, and **never push a
  GPU kernel without that number**: Kaggle does not refuse a kernel when the quota is short, it accepts it and
  runs on (2026-10-01: I pushed a ~7 h run on an unknown quota; it was at 0 h by morning).
  **Why:** "chạy trên local làm máy tôi nóng quá" (2026-09-28); the per-session charge was verified by the user
  on 2026-09-29. 2026-09-30: "Chạy test nhỏ trên local GPU trước khi đưa lên bất cứ đâu, để phát hiện lỗi và khắc
  phục sớm nhất, trường hợp được dùng local GPU để chạy khi mà task đủ để chạy trên local + các nền tảng khác cần để
  dành cho những tasks quan trọng hơn cần GPU tốc độ cao". Clarified the same day: "nên ưu tiên cho các nền tảng ngoài task nặng
  nhất … task vẫn còn nhưng nặng thì cũng để đấy chứ không dùng local".
- **Time and cost estimates only from measured references** — timings of an earlier run of the same step,
  rates logged by the job (documents/s, s per query), prices from the provider — with the basis shown next to
  the number. Mark unmeasured parts "unknown" and say which measurement would give them; never pad them with
  a guess.
  **Why:** 2026-09-28, several of my estimates were wrong (3–5 h against ~24 GPU-h; kernels "done by 18–19h"
  that had started at 18:30). User: "Chỉ khi nào bạn chắc chắn về khoảng thời gian hoặc có mốc thời gian để ước
  lượng thì mới được nói khoảng bao nhiêu time, đừng ước lượng mù mịt".

## Long and remote runs

- **A job that may run over ~10 minutes checkpoints and resumes.** Build it in before the first long run:
  - Append each finished unit (measurement, batch, epoch) to a file keyed by the run's signature (model, data,
    config, seed), `fsync` after each write, and tolerate a line torn by a power cut; a rerun of the same
    command skips what is done, a changed run starts afresh. Delete the checkpoint only after the final result
    is written. Test the resume by killing a small run midway.
  - Training: save model, optimizer, scheduler and RNG state periodically and on SIGTERM; resume from the
    latest.
  - Launch detached (`setsid nohup … > log 2>&1 &`), log inside the project (not /tmp, cleared on reboot),
    flush progress lines, and give the user the exact resume command. Detaching survives the session ending,
    not the machine sleeping or shutting down — only the checkpoint covers that.
  - Kill processes by PID; never `pkill -f` with a pattern that also matches the current shell's command line.
    The same holds for waiting: wait on a PID (`while kill -0 PID`), never on `pgrep -f PATTERN` — the waiting
    shell's own command line holds the pattern, so the loop never ends (2026-10-01: two such loops idled for hours).
  **Why:** 2026-09-25, a 2.5-hour benchmark was lost twice (session end, laptop shutdown). User: "nhớ cho các
  projects sau nếu phải chạy phiên dài thì luôn phải lưu checkpoint".
- **A remote run (Kaggle, Modal, any cloud job) must work the first time.**
  1. Run the whole pipeline end to end locally on a tiny input with fake models (CPU), so every line the
     remote run takes has executed once; then a small test with the real models on the local GPU.
  2. Then at most **one** short smoke run on the platform that repeats the real run's sequence (several items
     per process, every stage including reports), with both GPUs busy; repeat it only if code changed after it.
  3. Build in guards: download retries with backoff, prefetch then offline, a preflight check of the
     environment (e.g. GPU memory held outside PyTorch), a deadline before the platform's limit, continue past
     a failing item and list the failures at the end, memory logging.
  4. After every run, read every log and output file in full (not just the tail) and cross-check the results
     (counts, bit-identical comparisons with earlier runs) before reporting.
  5. Keep what is needed to reuse or re-analyse results: a manifest (commit, pinned data and model revisions,
     package versions, hardware) and intermediates (candidates, scores); leave bulky reusable artifacts on the
     platform.
  **Why:** 2026-09-28, peresearch: the first smoke ran one corpus per process and missed a JAX GPU grab that
  killed every full-run worker; my next edit added a NameError; three smoke runs in one day. User: "lắm smoke
  test quá đấy", "xây chắc chắn để có thể xử lý mọi vấn đề", "phòng trừ mọi trường hợp", "Hãy đọc hết output
  … đọc kỹ và xử lý nếu có vấn đề".

## Bugs and results

- **Reproduce before fixing.** A suspected bug is not a bug until a test (or minimal run) shows the failure.
  Once the fix is approved (see "Ask before acting"): write the failing test, show it fails, fix, show it passes
  together with the full suite, and report the failing output as evidence.
  **Why:** 2026-09-29, a stale-cache bug I reported: "test xem đúng không mới sửa".
- **Hidden hazards are handled, not skipped.** When a change touches a path not yet exercised (a new code path,
  another protocol, another platform), list every such path before calling the work done and check each one
  (a test that reproduces the failure mode, a run against the real component). A step is not "done" while a known
  hazard is unchecked, unless the check needs something unavailable (e.g. a paid platform not yet usable); then
  name it as open and put it on that step's checklist.
  **Why:** 2026-09-29, peresearch: the Esc fix first closed the client from another thread, and vLLM went on
  generating for 55.7 s; after the fix I listed five unchecked paths. User: "Luôn ưu tiên xử lý triệt để những
  hiểm họa ngầm, đừng bỏ qua chúng."
- **Doubtful results → one clean rerun from scratch** at a single commit rather than stitching partial or
  reused results, even if reuse saves compute; earlier runs are kept only for cross-checks. After a failure,
  always offer the clean rerun as an explicit option with its measured cost.
  **Why:** "Đo lại hết, mấy lần chạy trước không đáng tin tí nào" and "làm lại từ đầu đi, lằng nhằng quá, chạy
  lại từ đầu cho chắc" (2026-09-28).

## Repositories

- **Lean.** Only what the project needs to run, reproduce and present its results. No planning documents, no
  duplicated logs or stale summaries (the per-project CLAUDE.md below is the one state file). What matters from a
  plan goes into the README
  (design, deviations) or a comment next to the code it protects; pre-registration evidence stays in git
  history, linked from the README by commit.
  **Why:** "Mấy cái plan của vitok xóa luôn cũng được… hơi thừa", "cái gì không cần đều xóa hết đi" (2026-09-26).
- **Clean up after each step.** Delete what will not be needed again; anything that may be needed later must
  stay reproducible (the script and pinned inputs that regenerate it). Show the user the deletion list first.
  **Why:** "xóa những phần thực sự không cần thiết … nếu phần cần xóa mà sau này sẽ dùng đến thì cần có biện
  pháp để tái lập được" (2026-09-28).
- **Repository names in Karpathy style**: lowercase, one word, a minimal prefix plus the thing (nanoGPT, minbpe,
  micrograd, nanochat). Descriptive labels such as "vi-superbpe" were rejected as clumsy; "vlm-speedrun" is
  only tolerated. Check GitHub and PyPI for collisions before proposing.
- **English for everything except study material**: code, comments, docstrings, CLI output, README, status
  files, Dockerfile, CI, commit messages, file names. American spelling, the field's standard (quantization,
  optimize, normalize, behavior, color). Vietnamese strings that are experimental inputs or test data stay
  byte-identical, with an English comment. Chat replies stay Vietnamese.
  **Why:** 2026-09-24, "dù ở project nào chỉ cần không phải phần tài liệu thiết kế để tôi học thì đều dùng tiếng
  anh hết"; 2026-09-26, "'Quantisation', sao lại sử dụng tiếng anh-anh vậy? Dùng đúng từ chuyên ngành chứ."
- **README layout like `~/wsl/README.md`**: a centered `<div>` with the title, `for-the-badge` shields.io badges
  (CI status, language and version, license; colors 498AF2 / A19654 / 6B7F4E) and a bold one-line pitch; `---`
  between major sections; tables for structured facts; `> **Note:**` callouts. Simple, not fancy. A restyle
  changes layout only — verify with a word-level diff that the text is unchanged.
  **Why:** "Sửa lại readme cho đẹp hơn … không cần cầu kỳ quá, tham khảo wsl repo là được" (2026-09-29).
- **"Commit" means commit and push** for the user's repositories. If the push fails (e.g. `~/wsl` has an HTTPS
  remote without stored credentials), push to `git@github.com:geminitt/<repo>.git` over SSH and report.
  **Why:** "có chứ commit rồi không push để làm gì?" (2026-09-24).

## Git

- The default branch is named **`main`**, never `master`.
- The user's personal study material does not go into a course/submission branch. Keep it on a separate branch
  (in nanovitok: an orphan branch `notes`, checked out as a worktree), not mixed into the submitted history.
- Commit messages use Conventional Commits:

  ```
  <type>(<optional scope>): <short imperative summary, lowercase, no trailing period>

  <optional body: as long as needed, wrapped at ~72 columns, explains what and why>

  <trailers, e.g. Co-Authored-By>
  ```

  - `type` is one of: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`, `build`, `ci`.
  - The subject line is one line (~72 characters max). Details go in the body, never in the subject.
  - A long body is fine; a non-standard subject is not.
  - Language: follow the repository's existing history (if it has none, use English).
  - Split unrelated changes into separate commits when practical.

## Tooling (the user's WSL machine)

- **Never install or use `uv` / `uvx`**, not even into the home directory.
- Layers: **apt** (system packages, following `~/wsl/apt-packages.txt` and `~/wsl/README.md`) → **mise** (Rust and
  other runtimes, general CLI tools; `~/.config/mise/config.toml`, symlinked from `~/wsl/mise-en-place/config.toml`)
  → **pixi** (per-project Python/ML environments, `~/.pixi/bin/pixi`).
- AI/ML command-line tools shared across projects (`hf`, `modal`, `kaggle`) go in **`pixi global`** from
  conda-forge, not mise (mise's pipx backend defaults to uv) and not a project. The global manifest is tracked in
  `~/wsl/pixi/pixi-global.toml` (`~/.pixi/manifests` symlinks there); expose only the commands needed
  (`pixi global expose remove …`) and commit and push `~/wsl` afterwards. The Python library a project imports
  still goes in that project's pixi environment.
- Pick the right layer before installing anything; **ask before anything that needs sudo**.

## Learning material

- Put theory **inside notebooks, interleaved with runnable code** (Karpathy-style: explain, then a cell that
  demonstrates or verifies it, ideally on real project data). Markdown-only theory without runnable parts is
  hard for the user to follow.
- **Cover every concept the project uses that is not "Solid"** in the knowledge inventory: at the start of a
  project, list those concepts, plan one notebook per gap, explain each from its definition (define → formula →
  when it applies → the project's own number), and order them so no notebook relies on a later one. The
  material lives on the study branch (see "Git").
  **Why:** 2026-09-24, vlm-speedrun shipped two short notebooks while using p-values, McNemar, Wilson intervals,
  power, bf16/fp16, quantization, KV cache… User: "phần tài liệu chỉ học ít vậy thôi hả? nền tảng của tôi đến
  đâu bạn nhớ chứ?"

## Formulas

- **In files** (notebooks, Markdown): LaTeX, inline `$...$`, display `$$...$$`. Vietnamese decimals inside math
  use `{,}` (e.g. `1{,}75`).
- **In chat replies: no LaTeX** — the VS Code Claude panel does not render it. Use Unicode math instead
  (Σ, ℓ̄ₙ, √, ≥, ×, subscripts), each formula on its own line, decimals with a plain comma (1,75).
- **Annotate only symbols the reader has not met yet** earlier in the text or the series; skip the note
  entirely if nothing is new. Keep it compact and structured: a bold label (**Ký hiệu mới**, **Lưu ý**,
  **Vì sao**), one short line per symbol, no long prose. Flag letters reused with a different meaning
  (e.g. B = bytes vs. batch size).

## Project state and memory

- **Each project keeps its current state in its own `CLAUDE.md`** at the repository root: commands, the
  architecture that takes several files to see, the owner's decisions for that project, the state of each step
  (done / failing / not done / waiting on what), open questions, and facts measured on the user's machine. It is
  the only record of that state: update it in the same step as the change, edit or delete superseded lines, never
  append a log. In a public repository keep it out of git (`.git/info/exclude`) unless the user decides otherwise.
  **Why:** 2026-09-29, "nên dùng CLAUDE.md cho từng project để lưu trạng thái hiện tại của nó như vậy giúp bạn
  không phải chỉnh sửa linh tinh trong memory, nhầm lẫn, quên hay bất kỳ trạng thái xấu nào nữa" — my memory had
  stale lines (an embedder shown as undecided after it was chosen, a wrong count of secret formats).
- **Memory** holds only what spans projects (e.g. the internship goal) and one pointer line per project to its
  `CLAUDE.md`. When something is decided, changed or superseded, fix it at once and never leave a contradictory
  line; when the user approves a batch ("duyệt hết"), move every item out of the open list immediately. When asked
  what I remember, re-read it and flag anything stale first.
  **Why:** 2026-09-29, my memory still listed approved items as open and showed an undecided choice as made. User:
  "Chỗ nào cũ hoặc mâu thuẫn thì cần phải chỉnh ngay hoặc xóa đi".

## User's knowledge inventory

Self-assessed on 2026-09-17. Calibrate every explanation against it; update it (with the date) when the user
reports having learned something.

**Solid**: Transformer block diagram and the attention formula; tokenization (BPE in depth, incl. SuperBPE);
optimizers (SGD, momentum, RMSprop, AdamW) and the training loop; dropout, weight init, batch/layer norm;
cross-entropy as a loss; entropy and KL as theory; descriptive statistics (mean, variance, standard
deviation); Python and basic numpy.

**Not yet** (explain before using in an argument):
- Inferential statistics — confidence intervals, p-values, hypothesis testing, bootstrap, effect size vs.
  significance, power.
- Perplexity and the link from entropy to bits per character / bits per byte.
- Large-scale training — LR schedules, gradient accumulation, mixed precision (fp16/bf16, loss scaling),
  distributed training (DDP, all-reduce).
- Transformer internals beyond attention — KV cache, RoPE, grouped-query attention, sliding window, value
  embeddings, Muon.
- Scaling laws and compute budgets — Chinchilla ratios, FLOPs ≈ 6ND, equal-text / equal-token / equal-FLOPs.
- Vietnamese linguistics and Unicode — syllable vs. word, tone placement, NFC/NFD, combining marks.
- Performance engineering — numpy vectorization beyond basics, complexity estimates (big-O), profilers.

(Study notebooks covering these exist in the nanovitok project (formerly vitok, at `~/projects/nanovitok`), branch
`notes`, at `docs/foundations/notebooks/`.)
