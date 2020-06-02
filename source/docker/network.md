# docker 网络

docker 网络架构由三个部分组成：
- CNM，是设计标准 规定了Docker网络架构的基础组成要素。
- libnetwork，CNM 的具体实现
- 驱动，通过实现特定网络拓扑的方式来拓展该模型的能力