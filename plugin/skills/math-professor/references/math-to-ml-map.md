# Math to ML map

Linear-algebra topic, ML payoff, LLM instance, source. For state 7: one sentence per session, never the whole entry.
Extend for other subjects only with a source you read.

- **Row reduction:** normal equations; LU with pivoting in every dense solver. Rank and pivots explain a singular XᵀX
  in a probe. [torch.linalg.lu_factor](https://docs.pytorch.org/docs/stable/generated/torch.linalg.lu_factor.html)
- **Span, Ax = b:** embeddings as vectors; representability is membership in a span. Linear representation hypothesis:
  concepts are directions. [arXiv:2311.03658](https://arxiv.org/abs/2311.03658)
- **Independence:** multicollinearity, rank-deficient design matrices. Dimensional collapse: embeddings span a strict
  subspace. [arXiv:2110.09348](https://arxiv.org/abs/2110.09348)
- **Linear maps:** every `nn.Linear`; composition is a product, so nonlinearity is mandatory. Q, K, V are learned
  linear maps; pure attention collapses to rank 1. [arXiv:2103.03404](https://arxiv.org/abs/2103.03404)
- **Inverse:** (XᵀX)⁻¹ in theory, `solve` and `lstsq` in practice. Preconditioners avoid inverses; flows require
  invertibility. [arXiv:1505.05770](https://arxiv.org/abs/1505.05770)
- **Subspaces, rank:** low-rank structure drives efficient adaptation. LoRA: ΔW = BA, up to 10,000x fewer trainable
  parameters on GPT-3 175B. [arXiv:2106.09685](https://arxiv.org/abs/2106.09685)
- **Determinants:** volume scaling; log det Σ in the Gaussian likelihood. Log-det Jacobian in flows; LLMs avoid it by
  autoregressive factorisation. [arXiv:1605.08803](https://arxiv.org/abs/1605.08803)
- **Eigenvectors:** PCA, power iteration; κ = λmax/λmin sets gradient-descent convergence. Hessian spectrum and why
  normalisation helps deep training. [arXiv:1901.10159](https://arxiv.org/abs/1901.10159)
- **Inner product, projection:** cosine similarity; least squares is orthogonal projection. LayerNorm projects onto
  the hyperplane orthogonal to the all-ones vector. [ACL Findings 2023](https://aclanthology.org/2023.findings-acl.895/)
- **Gram-Schmidt, QR:** QR is the production least-squares algorithm. Muon orthogonalises momentum by Newton-Schulz.
  [Jordan 2024](https://kellerjordan.github.io/posts/muon/)
- **Least squares:** closed-form regression; ridge is regularised normal equations. Frozen features plus one linear
  layer is the linear probe. [arXiv:1610.01644](https://arxiv.org/abs/1610.01644)
- **Spectral theorem, SVD, PCA:** Eckart-Young makes truncated SVD the best rank-k approximation. PiSSA initialises
  LoRA from principal singular vectors. [arXiv:2404.02948](https://arxiv.org/abs/2404.02948)
