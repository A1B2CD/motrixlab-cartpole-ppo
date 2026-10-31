# MotrixLab CartPole PPO — 第 7 讲训练闭环（云端运行）

第五期「强化学习与 MotrixLab 入门」第 7 讲实操作业仓库：在**巧工云 GPU 服务器**上跑通 CartPole PPO 训练闭环，并把三项运行证据（输出目录 / TensorBoard 曲线 / `play.py` 推理）连同原始日志、checkpoint 一起归档到本仓库。

- 上游框架：[Motphys/MotrixLab](https://github.com/Motphys/MotrixLab) tag `v0.3.0`（Apache-2.0）
- 课程文档仓库：[Xbotics-Embodied-AI-club/Motphys-Xbotics-Robot-Rl-Sim-Training-Camp](https://github.com/Xbotics-Embodied-AI-club/Motphys-Xbotics-Robot-Rl-Sim-Training-Camp)
- 环境名：`cartpole`

---

## 1. 仓库结构

```text
.
├── README.md                     # 本文件
├── docs/
│   └── 第7讲实操教程与指南.md      # 完整教程：下载、安装、训练、TensorBoard、推理、硬件/架构分析
├── scripts/                      # 云端一键脚本（按编号顺序执行）
│   ├── lib.sh                    # 公共变量与函数
│   ├── 00_check_server.sh        # 采集服务器硬件/软件配置
│   ├── 01_bootstrap.sh           # 装系统依赖 + uv + Python3.10 + uv sync
│   ├── 02_train.sh               # 训练，产出 runs/cartpole/<时间戳>_PPO/
│   ├── 03_tensorboard.sh         # 启动 TensorBoard（含 SSH 隧道说明）
│   ├── 03_tensorboard_stop.sh    # 停止 TensorBoard
│   ├── 04_export_scalars.sh      # 从 tfevents 导出 CSV + 曲线 PNG（无浏览器也能出图）
│   ├── 05_play_headless.sh       # 推理演示（headless，100% 可复现）
│   ├── 06_play_xvfb.sh           # 推理演示（xvfb 虚拟显示 + 截图，尽力而为）
│   ├── 07_collect_evidence.sh    # 汇总目录树 / 校验和 / 清单
│   ├── 08_push_evidence.sh       # 提交并推回 GitHub
│   └── run_all.sh                # 一键跑完 00 → 07（截图需人工确认）
├── evidence/
│   ├── cloud/                    # 云端生成的证据（服务器跑完自动写入）
│   └── local-windows/            # 本地 Windows 机器的对照运行证据
└── motrixlab/                    # vendored MotrixLab v0.3.0（含本项目的修改）
    ├── motrix_envs/              # 环境实现层：EnvCfg / Env / Reward
    ├── motrix_rl/                # 训练算法层：SKRL PPO、注册表、checkpoint
    ├── scripts/                  # train.py / play.py / view.py
    ├── tools/check_env.py        # 硬件/软件报告脚本（本项目新增）
    └── runs/cartpole/            # 训练输出（checkpoint + tfevents）
```

> `motrixlab/` 是把上游 v0.3.0 源码整体 vendored 进来，**不是子模块**。这样在 github.com 不可达的机器上也能直接 `git clone` 本仓库跑起来，无需再访问上游。
>
> **关于 LFS 资产**：上游用 Git LFS 跟踪 `*.stl / *.obj / *.png / *.mp4`，但 GitHub 上 v0.3.0 的源码包里这些文件只是 130 字节的指针。本仓库已删除全部指针文件并移除 LFS 规则，只把 **CartPole 唯一需要的 `motphys-ground.png` 替换成真实文件**（56,655 字节）。因此 CartPole 可完整运行；`anymal_c`、`franka_*`、`shadow_hand` 等其他环境的网格/贴图缺失，无法运行（需要时请从上游按 LFS 重新拉取）。

---

## 2. 三项运行证据

判定口径（《课程作业完成指标-前两周》）：不要求训满 `max_env_steps=10_000_000`，满足"≥1 个 episode 完成训练闭环、日志目录存在、能启动 TensorBoard 并出图、`play.py` 可加载任一 checkpoint 演示"即可。

| # | 证据 | 分值 | 云端文件 | 本地对照文件 |
| --- | --- | --- | --- | --- |
| 1 | 输出目录 `runs/cartpole/<时间戳>_PPO/`，含 `checkpoints/` 或 `events.out.tfevents.*` | 8 | `evidence/cloud/07_runs_tree.txt`、`02_train_console.log` | `evidence/local-windows/01_runs_directory.png`、`01b_explorer_view.png` |
| 2 | `uv run tensorboard --logdir runs/cartpole` 的 reward/loss 曲线 + 一句话结论 | 10 | `evidence/cloud/03_tensorboard_reward_loss.png`、`04_*.png`、`04_scalars.csv`、`04_summary.md` | `evidence/local-windows/05_tensorboard_reward_loss.png` |
| 3 | `uv run scripts/play.py --env cartpole --policy <checkpoint>` 加载成功 + 一句话结果 | 12 | `evidence/cloud/05_play_headless.log`、`06_play_xvfb.png` | `evidence/local-windows/03_play_demo.png` |

云端证据生成后，`evidence/cloud/README.md` 会自动汇总成提交用的一页纸。

---

## 3. 在巧工云服务器上跑（完整流程）

### 3.1 准备

```bash
# 登录实例（巧工云 Web 终端或 SSH）
nvidia-smi                 # 确认 GPU / 驱动 / CUDA 版本
git --version
```

需要：Ubuntu 22.04（或 20.04）+ 可 `sudo`。Python 由 uv 自动装，不用预装。

### 3.2 拉代码

```bash
git clone https://github.com/A1B2CD/motrixlab-cartpole-ppo.git
cd motrixlab-cartpole-ppo
```

### 3.3 按顺序执行

一键跑完（推荐）：

```bash
bash scripts/run_all.sh
```

或逐条执行：

```bash
bash scripts/00_check_server.sh      # 记录服务器配置 → evidence/cloud/00_server_report.*
bash scripts/01_bootstrap.sh         # 装依赖 + uv sync（首次 3-8 分钟）
bash scripts/02_train.sh             # 训练 → runs/cartpole/<时间戳>_PPO/
bash scripts/03_tensorboard.sh       # 启动 TensorBoard（另开终端做 SSH 隧道看曲线）
bash scripts/04_export_scalars.sh    # 导出 CSV + 曲线 PNG（服务器端出图）
bash scripts/05_play_headless.sh     # 推理演示（headless）
bash scripts/06_play_xvfb.sh         # 推理演示（xvfb 截图，可选）
bash scripts/03_tensorboard_stop.sh  # 截完图停掉 TensorBoard
bash scripts/07_collect_evidence.sh  # 汇总清单与校验和
bash scripts/08_push_evidence.sh     # 推回 GitHub
```

`01_bootstrap.sh` 会自动判断该用哪版 PyTorch：

| 驱动 / CUDA | 选用轮子 |
| --- | --- |
| `nvidia-smi` 显示 CUDA ≥ 12.8（驱动 ≥ 570） | `torch==2.7.0+cu128`（GPU） |
| 无 GPU，或 CUDA < 12.8 | `torch==2.7.0+cpu`（CPU） |

也可以强制：`TORCH_VARIANT=cpu bash scripts/01_bootstrap.sh`。

### 3.4 看 TensorBoard（关键：不要在服务器上开浏览器）

TensorBoard 默认只监听 `127.0.0.1:6006`。在你**自己的电脑**上建 SSH 隧道：

```bash
ssh -N -L 6006:127.0.0.1:6006 <user>@<server-ip> -p <ssh-port>
```

然后本机浏览器打开 <http://127.0.0.1:6006>，进 **SCALARS** 页签，把 `Reward` 和 `Loss` 两组展开截图，存为 `evidence/cloud/03_tensorboard_reward_loss.png`。

> 如果巧工云提供 Web 端口映射，可以 `HOST=0.0.0.0 bash scripts/03_tensorboard.sh` 直接映射端口——但**优先用 SSH 隧道**，不要把 6006 裸奔在公网。

### 3.5 认证与推送

服务器上没有你的浏览器登录态，二选一：

**A. Deploy key（推荐）**

```bash
ssh-keygen -t ed25519 -C "qiaogong-server" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
# 复制到 GitHub → 仓库 → Settings → Deploy keys → Add deploy key（勾选 Allow write access）
ssh -T git@github.com
```

**B. PAT over HTTPS**

```bash
export GH_TOKEN=ghp_xxxxxxxx
git remote set-url origin https://x-access-token:${GH_TOKEN}@github.com/<owner>/motrixlab-cartpole-ppo.git
```

---

## 4. 本项目的关键修改（相对上游 v0.3.0）

| 文件 | 修改 | 原因 |
| --- | --- | --- |
| `motrixlab/motrix_rl/src/motrix_rl/skrl/__init__.py` | `get_log_dir()` 返回 `runs/<env>` 而不是 `runs/<env>/skrl` | 作业要求目录形如 `runs/cartpole/<时间戳>_PPO/` |
| `motrixlab/scripts/play.py` | 只给 `--policy` 时按后缀自动推断 `--rllib` | 上游强制要求 `--rllib`，作业命令里没有 |
| `motrixlab/scripts/play.py` | 新增 `--headless`；Linux 无 `DISPLAY` 时自动降级 | 云服务器无显示器，Bevy 无法建窗口 |
| `motrixlab/motrix_rl/src/motrix_rl/skrl/torch/train/ppo.py` | `Trainer.play()` 支持 `PLAY_MAX_STEPS`；headless 时不按 60fps 限速 | 自动化取证需要跑完即退出 |
| `motrixlab/pyproject.toml`、`motrix_rl/pyproject.toml` | PyTorch 索引改为可变（cpu / cu128），加清华 tuna 镜像 | 国内网络 + 本地老驱动 |
| `motrixlab/motrix_envs/pyproject.toml` | `motrixsim>=0.7.0` → `==0.7.0` | 锁版本，避免重新解析升到不兼容版本 |
| `motrixlab/tools/check_env.py` | 新增 | 一键输出硬件/软件报告，本地和云端都能跑 |
| `motrixlab/.gitattributes` | 移除上游全部 `filter=lfs` 规则；删除 400 个 LFS 指针文件 | GitHub pre-receive 钩子会拒绝含指针的推送（`GH008 ... unknown Git LFS objects`）；CartPole 不需要这些网格/贴图 |

以上修改**不改变训练算法、超参和 checkpoint 格式**。

---

## 5. 软件架构（对应教程第 8 节）

```text
用户接口层   scripts/train.py  scripts/play.py  scripts/view.py
     ↓
训练算法层   motrix_rl   registry.py / tasks/cartpole.py / skrl/torch/train/ppo.py
     ↓
环境实现层   motrix_envs basic/cartpole/{cfg.py, cartpole_np.py, cartpole.xml}
     ↓
物理仿真层   motrixsim 0.7.0（np 后端 / MotrixSim 引擎，Bevy 渲染）
```

两套注册表必须同名 `cartpole`：

```text
motrix_envs.registry:  @envcfg("cartpole") → CartPoleEnvCfg
                       @env("cartpole","np") → CartPoleEnv
motrix_rl.registry:    @rlcfg("cartpole")   → CartPoleSkrlPpo / CartPoleRlsrlPpo
```

日志与模型由 SKRL `SequentialTrainer` 统一写入 `runs/<env>/<时间戳>_PPO/`，天然可复现。

---

## 6. 复现命令一页纸

```bash
git clone https://github.com/A1B2CD/motrixlab-cartpole-ppo.git
cd motrixlab-cartpole-ppo
bash scripts/01_bootstrap.sh

cd motrixlab
uv run scripts/train.py --env cartpole --num-envs 64
uv run tensorboard --logdir runs/cartpole
uv run scripts/play.py --env cartpole \
  --policy runs/cartpole/<时间戳>_PPO/checkpoints/best_agent.pt --headless
```

---

## 7. 许可

`motrixlab/` 目录为 Motphys 的 Apache-2.0 代码，原始 `LICENSE` 与 `NOTICE` 保留在 `motrixlab/` 内。本项目新增的脚本与文档同样以 Apache-2.0 发布。
