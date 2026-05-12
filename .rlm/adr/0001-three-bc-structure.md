# Three Bounded Contexts: Intake, Design, Delivery

The system has three Bounded Contexts — Intake, Design, Delivery — each with its own ubiquitous language. The same artifact (Spec, WorkPackage, Artifact, PR) means different things at different stages and carries different metadata; treating them as one model produces ambiguity.

Validation was rejected as a separate BC because validation is one phase of the Delivery cycle, not a separate domain. WhiteBoxValidator and BlackBoxValidator are agents *within* Delivery's pipeline (coordinated by the DeliveryOrchestrator per [ADR-0014](./0014-delivery-orchestrator.md)); BlackBoxValidator's structural separation from code is a context-window discipline ([ADR-0006](./0006-validation-pipeline.md), [ADR-0009](./0009-resource-access-boundaries.md)), not a Bounded Context boundary. Making validation a BC would force pipeline-stage language into separate vocabularies and reintroduce coordination problems Delivery already solves.

**Note: BCs are *language boundaries*, not agent boundaries.** The same agent may operate across multiple BCs as long as the language distinction is preserved internally — see [ADR-0008](./0008-hermes-scope-lifecycle-governance.md), where Hermes is the operational owner of both Intake and Design despite their distinct vocabularies.
