
### Top Level

The **tanimoto_top** module implements the top level pipeline. It instantiates **vec_cat** on the input. Sub-vectors leaving the concatenator module are fed through a **cnt1** module. The resulting binary weights are stored in shiftregisters, alongside the vectors themselves.
The pipeline is controlled by an FSM with two states. In the LOAD_REF state, vectors and their weights are loaded into the reference shiftregisters. After SHR_DEPTH number of vectors have been received, the pipeline is switched to the COMPARE state. In this state, incoming vectors and their corresponding weights are shifted through compare shiftregisters. Every two cycles (depends on how many bus cycles a full fingerprint is received in), compare and reference vectors on the same index are put through AND gates, the result of which is fed to a **cnt1** module (which are instantiated SHR_DEPTH times).
The results are then passed to comparator modules, which determine whether the compare and reference vectors are over or under the programmed Tanimoto threshold.
Vector IDs, that are propagated alongside the vector weight, are then either discarded, or recorded to a FIFO-tree (a hierarchical elastic memory buffer), which propagates them to the output of the top module.

#### Block diagram

Draw.io managed to not save the top-level block diagram three times in a row, even though I clearly told it to. Thus, this remains a TODO for now.