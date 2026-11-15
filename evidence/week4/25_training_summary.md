# 第 4 周训练产物汇总

- 生成时间：2026-11-15T20:37:43+08:00
- 主机：cdl8js5vb8-767c7cf587-psjqq
- 仓库提交：7a45686

| 标签 | 模型路径 | 大小 | TensorBoard 事件文件 |
| --- | --- | --- | --- |
| `acrobot_demo` | `motrixlab/runs/week4/acrobot_demo/checkpoints/best_agent.pt` | 40K | `motrixlab/runs/week4/acrobot_demo/events.out.tfevents.1794745597.cdl8js5vb8-767c7cf587-psjqq.21350.0` |
| `pendulum_A` | `motrixlab/runs/week4/pendulum_A/checkpoints/best_agent.pt` | 88K | `motrixlab/runs/week4/pendulum_A/events.out.tfevents.1794744003.cdl8js5vb8-767c7cf587-psjqq.14123.0` |
| `pendulum_B` | `motrixlab/runs/week4/pendulum_B/checkpoints/best_agent.pt` | 88K | `motrixlab/runs/week4/pendulum_B/events.out.tfevents.1794744116.cdl8js5vb8-767c7cf587-psjqq.15220.0` |
| `pendulum_demo` | `motrixlab/runs/week4/pendulum_demo/checkpoints/best_agent.pt` | 88K | `motrixlab/runs/week4/pendulum_demo/events.out.tfevents.1794742036.cdl8js5vb8-767c7cf587-psjqq.5427.0` |

## 回放命令模板

```bash
ENV=acrobot TAG=demo SEED=0 bash scripts/21_record_episode.sh
ENV=pendulum TAG=A SEED=0 bash scripts/21_record_episode.sh
ENV=pendulum TAG=B SEED=0 bash scripts/21_record_episode.sh
ENV=pendulum TAG=demo SEED=0 bash scripts/21_record_episode.sh
```
