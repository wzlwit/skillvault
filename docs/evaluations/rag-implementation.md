# RAG Implementation Evaluation

- Evaluated: 2026-09-27
- Source: https://github.com/wshobson/agents
- Skill directory: `plugins/llm-application-dev/skills/rag-implementation`
- Reviewed revision: `9b15b34b0bfc13a815cbfc2366e14ea549e09422` (2026-09-26)
- Author: Seth Hobson
- License: MIT; repository license and containing plugin manifest agree
- Skill version: Not declared
- Containing plugin: `llm-application-dev`, manifest version `2.0.6`; README highlights `2.0.0`
- Scope: Building document question-answering and other retrieval-augmented generation systems

## Recommendation

Purpose: Help a coding agent select and assemble document chunking, embeddings, retrieval,
reranking, and grounded answer generation. Audience: developers implementing a knowledge-backed
assistant or improving an existing retrieval pipeline.

Value: **High as design guidance.** Fit: A focused skill, not a single prompt or always-on rule.
The target contains two Markdown files: its entrypoint and a detailed reference. It is not a
standalone RAG application, database, or executable service.

Skill status: **Original repository-only reference entry added locally** named
`rag-implementation` under `skills/data/`, kind `reference`, with version null. Retain Seth
Hobson's attribution and the pinned source. The containing plugin's version must not become an
invented version for an independently written reference. Global availability may be its future
installation default, but no new installation is implied.

Suggested description: "Reference to RAG implementation guidance for document Q&A, chunking,
retrieval, reranking, and grounded answers. Upstream examples require dependency and behavior
checks; no RAG runtime or data access is bundled."

MIT also permits a properly attributed adaptation, but a runnable adaptation would first need
the example repairs and task-specific verification below. Do not import the whole plugin or add
its cloud providers merely to make this guide available.

Installed recommendation: **Coexist; replace nothing.** `harness-doc` owns reader documentation
and evidence handling, not an application's retriever. `skillvault-authoring` owns skill creation
and comparative checks, not deployment of a RAG system. Their existing workflows are complementary.

Standalone usefulness: Worth using as a learning/design checklist and as a starting point for an
explicitly approved small prototype. The selected model, storage, provider access, dependency
versions, and data permissions must be supplied by that project; they are not established here.

Harness integration: **Defer runtime integration.** A reference can inform an approved development
task without a new harness action, background indexer, vector store, or automatic ingestion of
local/private files.

The approved follow-up added the reference and the single native improvement below. See
[Applied Locally](#applied-locally) for validation and installed-copy scope.

## Capability Fit

| Area | Useful guidance | Limitation |
| --- | --- | --- |
| Basic RAG pipeline | LangGraph retrieval and answer-generation stages | Assumes an already populated vector index and configured providers; it does not deliver a working document ingestion service. |
| Chunking | Character, token, semantic, and Markdown-heading strategies; parent/child retrieval | Example sizes and overlaps are starting points, not measured optima for the user's corpus or language. |
| Retrieval quality | Dense and keyword search, reciprocal rank fusion, multiple queries, context compression, and hypothetical-document retrieval | Extra stages add dependencies and model calls; benefits need comparison on representative questions. |
| Reranking and storage | Cross-encoder/API reranking and several vector-store examples | Choose the existing approved stack; no single database or reranker is shown to be best universally. |
| Grounded answers | Context-only prompts, uncertainty, citations, and structured responses | Prompted citations and self-reported confidence do not establish correct source attribution or calibrated accuracy. |
| Evaluation | Separate retrieval precision/recall and answer-quality measures | The example evaluator needs empty-case handling, explicit identities, and a real answer-quality implementation. |

## Concrete Limitations

1. **Dependency mismatch.** The plugin README requires LangChain 1.x, but the detailed examples
   still import retrievers from `langchain.retrievers` and storage from `langchain.storage`.
   LangChain's official v1 migration guide places legacy retrievers in `langchain-classic` and
   requires updated imports. These examples should not be presented as runnable unchanged under
   the stated stack. Provider packages and actual model IDs also need project-level verification.
2. **Empty evaluation cases.** The example divides an intersection count by the number of retrieved
   IDs and by the number of relevant IDs, without checking either denominator. An empty retrieval
   or empty relevance set therefore reaches division by zero. An empty test set also leaves empty
   averages. Define scoring conventions explicitly rather than dropping difficult cases or treating
   unavailable evidence as a passing score.
3. **Evaluation identity and completeness.** The sample requires `metadata['id']`, relevance labels,
   and an externally defined `evaluate_answer_quality`. Its use of sets deduplicates IDs; whether
   those identify chunks or source documents changes the metric. The earlier examples do not
   establish a complete labeled dataset or scoring implementation.
4. **Citation binding.** The quick-start generation step concatenates document bodies. A later
   prompt asks for numbered citations, but this is not a complete example of mapping those numbers
   to stable source IDs, revisions, and passages and checking that each cited passage supports
   the answer. This matters for practical document Q&A.
5. **Production boundaries are not demonstrated.** The category-filter example is not proof of
   user/tenant authorization. Before private deployment, establish permitted sources, provider
   transfers, access-filter enforcement, and treatment of retrieved text as evidence rather than
   instructions. Index refresh/removal and sensitive logging also need the project's own contract.
   These are unverified deployment concerns, not a security-audit verdict on a running service.

The reusable concepts remain valuable despite these example defects. The skill's claims about
accuracy or reduced hallucinations are goals, not guarantees. No retrieval-quality, latency, cost,
Windows compatibility, or Chinese/multilingual benchmark was run in this evaluation.

## Existing-Skill Improvement

### Retrieval-Aware Comparative Checks

- Target: `skillvault-authoring`, **Comparative outcome checks** in its
  [upsert workflow](../../skills/core/skillvault-authoring/references/upsert.md).
- Evidence and gap: The RAG reference separates retrieval and answer metrics but leaves empty
  denominators and identity assumptions unresolved. Before this update, authoring guidance required
  matched baselines, measured units, complete comparable pairs, and unavailable metrics to remain
  unavailable. It did not spell out how to separate retrieval from generation in a retrieval-backed
  skill comparison.
- Applied change: Only for a requested retrieval-backed comparison, hold the corpus revision,
  source permissions, questions, and relevance labels fixed; record retrieval results separately
  from final-answer correctness and citation support. State whether metrics count chunks or
  documents, how duplicate IDs are handled, and which denominators are defined. Include valid
  no-answer and empty-retrieval cases; distinguish these from missing labels or execution failure.
  Reuse existing notes and test tooling, without a compulsory judge model, new service, or automatic
  evaluation run. Non-retrieval skills keep the existing comparison procedure.
- Expected benefit: Make it possible to tell whether a change improved source retrieval, answer
  generation, or neither, without a fluent answer masking a retrieval failure.
- Validation: For a labeled answerable question, empty retrieval must not become a clean retrieval
  result. For a genuinely unanswerable question, correct abstention can pass its answer criterion
  while a metric with no defined relevance denominator is reported as not applicable. Duplicate
  chunks from one document must not inflate document-level coverage. An ordinary formatting-skill
  comparison requires no retrieval dataset or extra model calls.

This was **the only native improvement applied**. The current
[documentation workflow](../../skills/planning/harness-doc/references/workflow.md) already requires
source/revision/section traceability, complete governing-section reads, extraction caveats, and
Draft outcomes for missing essential evidence. No additional documentation change is justified by
the citation lesson alone. RAG-specific example fixes belong in a future adaptation, not unrelated
skills or global rules.

## Evidence and Verification

The exact candidate and revision were reused from the preceding search. That search checked 55
global/current-project skill folders and both 40-entry local/official catalogs, found no dedicated
RAG entry, and reported the optional cache absent. No configured internal skill catalog was supplied.
The current evaluation did not repeat that discovery or select a different RAG project.

Inspected material: the full RAG entrypoint and detailed examples, plugin README and manifest,
repository license, the official LangChain v1 migration section, and complete relevant sections of
the local authoring and documentation guides. Their installed global copies matched the source at
evaluation time.
The pinned tree confirms the RAG skill has only its two Markdown files; no own scripts, tests, or
manifest were found in that directory. The neighboring hybrid-search and LLM-evaluation entrypoints
were read during the search but are not independently evaluated or selected for installation here.

No upstream example, provider API, vector database, application, or model benchmark was executed.
Compatibility and empty-case findings are source/documentation analysis, not test-run results.
The evaluation itself added only this public-safe record. The subsequent approved source and
existing-copy changes are summarized below; no upstream execution is implied.

Reconsider executable adoption after an approved prototype establishes current imports, explicit
source/citation identities, answerable and unanswerable cases, access boundaries where needed,
and measured retrieval/answer outcomes on the intended corpus. Recheck this record when the source
revision or required stack changes.

## Applied Locally

On 2026-09-27, the approved follow-up added the original
[RAG reference](../../skills/data/rag-implementation/SKILL.md), its manifest, catalog entry, and
README navigation. Upstream author, MIT license, and revision are retained; both the reference
and upstream skill versions remain null. No upstream prompts, examples, scripts, or runtime were
copied, repaired, or executed. The reference remains uninstalled globally and in the project.

The authoring workflow now includes conditional retrieval-backed comparisons with separate
retrieval and answer/citation outcomes, explicit metric units and denominators, document-level
deduplication, and the four edge cases above. Ordinary formatting comparisons gain no retrieval
dataset requirement or additional model calls. No documentation workflow, runtime, or rule changed.

Validation: four focused Node contracts passed, including the new reference and retrieval checks
and the existing comparison/trigger checks. Catalog/resource validation passed for 41 public skills
and 30 project copies; editor diagnostics were clean. Instruction review covered answerable/empty,
unanswerable/abstention, duplicate-chunk, missing-evidence, and non-retrieval cases. Explicit and
implicit RAG design requests belong to the reference; skill evaluation stays with discovery and
plain formatting requires no RAG guidance. These were instruction walkthroughs, not observed host
trigger tests or model benchmarks.

The existing managed global `skillvault-authoring` latest copy was previewed and refreshed through
the guarded installer, then verified against source. Its installation companion already matched
and was left unchanged. The missing project authoring copy stayed absent. No new skill installation,
data ingestion, provider call, schedule change, or publication occurred.

## Sources

- [Pinned RAG entrypoint](https://github.com/wshobson/agents/blob/9b15b34b0bfc13a815cbfc2366e14ea549e09422/plugins/llm-application-dev/skills/rag-implementation/SKILL.md)
- [Detailed RAG examples](https://github.com/wshobson/agents/blob/9b15b34b0bfc13a815cbfc2366e14ea549e09422/plugins/llm-application-dev/skills/rag-implementation/references/details.md)
- [Plugin requirements](https://github.com/wshobson/agents/blob/9b15b34b0bfc13a815cbfc2366e14ea549e09422/plugins/llm-application-dev/README.md)
- [Plugin manifest](https://github.com/wshobson/agents/blob/9b15b34b0bfc13a815cbfc2366e14ea549e09422/plugins/llm-application-dev/.claude-plugin/plugin.json)
- [MIT license](https://github.com/wshobson/agents/blob/9b15b34b0bfc13a815cbfc2366e14ea549e09422/LICENSE)
- [LangChain v1 migration](https://docs.langchain.com/oss/python/migrate/langchain-v1)