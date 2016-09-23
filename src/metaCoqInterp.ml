open Constrs

module MetaCoqRun = struct
  (** This module run the interpretation of a constr
  *)

  open Proofview.Notations

  (**  *)
  let pretypeT env sigma t c =
    let metaCoqType = Lazy.force Run.MetaCoqNames.mkT_lazy in
    let sigma, tacticType = MCTactics.mkTactic sigma env in
    let ty = Retyping.get_type_of env sigma c in
    let (h, args) = Reductionops.whd_betadeltaiota_stack env sigma ty in
    if Term.eq_constr_nounivs metaCoqType h && List.length args = 1 then
      try
        let sigma = Evarconv.the_conv_x_leq env t (List.hd args) sigma in
        (sigma, c)
      with Evarconv.UnableToUnify(_,_) -> Errors.error "Different types"
    else if Term.eq_constr_nounivs tacticType ty && List.length args = 0 then
      let sigma, runTac = MCTactics.mkRunTac sigma env in
      (sigma, Term.mkApp(runTac, [|t; c|]))
    else
      Errors.error "Not a Mtactic"

  let run env sigma concl c =
    let (sigma, t) = pretypeT env sigma concl c in
    let rec aux = function
      | Run.Val (sigma, v) ->
          Proofview.Refine.refine ~unsafe:false (fun _ -> (sigma, v))
      | Run.Err (_, e) ->
          Errors.error ("Uncaught exception: " ^ Pp.string_of_ppcmds (Termops.print_constr e))
    in
    aux (Run.run (env, sigma) t)

  (** Get back the context given a goal, interp the constr_expr to obtain a constr
      Then run the interpretation fo the constr, and returns the tactic value,
      according to the value of the data returned by [run].
  *)
  let run_tac t =
    Proofview.Goal.nf_enter begin fun gl ->
      let env = Proofview.Goal.env gl in
      let concl = Proofview.Goal.concl gl in
      let sigma = Proofview.Goal.sigma gl in
      let (sigma, c) = Constrintern.interp_open_constr env sigma t in
      run env sigma concl c
    end


  let understand env sigma {Glob_term.closure=closure;term=term} =
    let open Pretyping in
    let flags = all_no_fail_flags in
    let lvar = { empty_lvar with
                 ltac_constrs = closure.Glob_term.typed;
                 ltac_uconstrs = closure.Glob_term.untyped;
                 ltac_idents = closure.Glob_term.idents;
               } in
    understand_ltac flags env sigma lvar WithoutTypeConstraint term

  let run_tac_constr t =
    Proofview.Goal.nf_enter begin fun gl ->
      let env = Proofview.Goal.env gl in
      let concl = Proofview.Goal.concl gl in
      let sigma = Proofview.Goal.sigma gl in
      let sigma, t = understand env sigma t in
      run env sigma concl t
    end

  let normalizer () =
    Proofview.Goal.nf_enter begin fun gl ->
      let env = Proofview.Goal.env gl in
      let concl = Proofview.Goal.concl gl in
      let sigma = Proofview.Goal.sigma gl in
      let reduceGoal = Lazy.force MCTactics.mkReduceGoal in
      match Run.run (env, sigma) (Term.mkApp (reduceGoal, [|concl|])) with
      | Run.Val (sigma, v) ->
          Proofview.Refine.refine ~unsafe:false (fun _ -> (sigma, v))
      | Run.Err _ ->
          assert false
    end
end

module MetaCoqProofInfos = struct
  (**
     This module concerns the state of the proof tree
  *)

  let proof_focus = Proof.new_focus_kind ()
  let proof_cond = Proof.no_cond proof_focus

  (** focus on the proof *)
  let focus () =
    Proof_global.simple_with_current_proof
      (fun _ -> Proof.focus proof_cond () 1)

  (** unfocus *)
  let maximal_unfocus () =
    (* we should make sure the evars are cleaned *)
    Proof_global.simple_with_current_proof (fun _ p  ->
      Proof.unshelve (Proof.V82.grab_evars p))

  let unfocus_if_done () =
    let pf = Proof_global.give_me_the_proof () in
    if Proof.is_done pf then
      maximal_unfocus ()
end

(**
   This module manages the interpretation of the MetaCoq tactics
   and the vernac MProof command.
*)

(** Interpreter of the MProof vernac command :
    - Get back and focus on the current proof
    - Set the proof mode to "MProof" mode.
    - Print subgoals *)
let interp_mproof_command () =
  let pf = Proof_global.give_me_the_proof () in
  if Proof.is_done pf then
    Errors.error "Nothing left to prove here."
  else
    begin
      Proof_global.set_proof_mode "MProof";
      Vernacentries.print_subgoals ();
    end

(** Interpreter of a mtactic *)
let interp_instr = function
  | MetaCoqInstr.MetaCoq_constr c -> MetaCoqRun.run_tac c

let exec f =
  ignore (Pfedit.by (f ()));
  MetaCoqProofInfos.unfocus_if_done ()

(** Interpreter of a constr :
    - Interpretes the constr
    - Unfocus on the current proof *)
let interp_proof_constr instr =
  exec (fun () -> interp_instr instr)


(** [end_proof] is "Qed" customized for MetaCoq.

    The standard "Qed" does not accept dangling evars even if they do
    not appear in the final ground proof term. This should probably
    be changed mainstream.

    In MetaCoq, we first check that the final proof term is ground
    and if it is, we explicitly remove the dangling evars from the
    environment so that the standard "Qed" does not complain.
*)
let end_proof () =
  let proof_is_closed_wrt_to_evars () =
    Proof_global.with_current_proof (fun _ proof ->
      proof, Proof.in_proof proof (fun evarmap ->
        let proofs = Proof.partial_proof proof in
        List.for_all (Evarutil.is_ground_term evarmap) proofs
      ))
  in
  let remove_dangling_evars () =
    ignore (Pfedit.by Proofview.(Unsafe.(Monad.(
      tclSETGOALS [] >>
      (tclEVARMAP >>= (fun evarmap ->
         let evarmap =
           Evd.fold_undefined (fun evar _ evarmap ->
             Evd.remove evarmap evar) evarmap evarmap
         in
         tclEVARS evarmap))))
    ));
  in
  if proof_is_closed_wrt_to_evars () then
    remove_dangling_evars ();
  (* The following invokes the usual Qed. *)
  Vernacentries.vernac_end_proof Vernacexpr.(Proved (Opaque None,None))
