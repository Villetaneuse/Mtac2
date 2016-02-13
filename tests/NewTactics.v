Require Import MetaCoq.MetaCoq.
Import MetaCoqNotations.

Require Import MetaCoq.LtacEmu.
Import LtacEmuNotations.

Require Import Strings.String.

Require Import Lists.List.
Import ListNotations.

Inductive goal :=
| TheGoal : forall {A}, A -> goal
| AHyp : forall {A}, (A -> goal) -> goal.


Notation tactic := (goal -> M (list goal)).

Definition exact {A} (x:A) : tactic := fun g=>
  munify g (TheGoal x);; ret nil.

Definition run_tac {P} (t : tactic) : M P :=
  e <- evar P;
  t (TheGoal e);;
  ret e.

Goal True.
MProof.
  run_tac (exact I).
Qed.

Goal False.
MProof.
  Fail run_tac (exact I).
Abort.

Definition close_goals {A} (x:A) : list goal -> M (list goal) :=
  mmap (fun g'=>r <- abs x g'; ret (@AHyp A r)).


Definition open_and_apply (t : tactic) : tactic := fix open g :=
    match g return M _ with
    | TheGoal _ => t g
    | @AHyp C f =>
      x <- get_name f;
      tnu x (fun x : C=>
        open (f x) >> close_goals x)
    end.


Definition NotSameSize : Exception. exact exception. Qed.
Fixpoint gmap (funs : list tactic) (ass : list goal) : M (list (list goal)) :=
  match funs, ass with
  | nil, nil => ret nil
  | f::funs', g::ass' =>
    fa <- open_and_apply f g;
    rest <- gmap funs' ass';
    ret (fa :: rest)
  | _, _ => raise NotSameSize
  end.

Definition bbind (t:tactic) (l:list tactic) : tactic := fun g=>
  l' <- t g;
  ls <- gmap l l';
  ret (concat ls).

Program Definition copy_ctx {A} (B : A -> Type) :=
  mfix1 rec (d : dyn) : M Type :=
    mmatch d with
    | [? C (D : C -> Type) (E : forall y:C, D y)] {| elem := fun x : C => E x |} =>
        nu y : C,
        r <- rec (Dyn _ (E y));
        pabs y r
    | [? c : A] {| elem := c |} =>
        ret (B c)
    end.

Definition CantCoerce : Exception. exact exception. Qed.

Definition to_goal d :=
  match d with
  | Dyn _ x => TheGoal x
  end.

Definition destruct {A : Type} (n : A) : tactic := fun g=>
  P <- evar (A->Type);
  Pn <- evar (P n);
  l <- constrs A;
  l <- LtacEmu.mmap (fun d : dyn =>
               t' <- copy_ctx P d;
               e <- evar t';
               ret {| elem := e |}) l;
  let c := {| case_ind := A;
              case_val := n;
              case_type := P n;
              case_return := {| elem := fun n : A => P n |};
              case_branches := l
           |} in
  d <- makecase c;
  d <- coerce (elem d);
  munify (@TheGoal (P n) d) g;;
  let l := simpl (List.map to_goal l) in
  ret l.

Definition reflexivity : tactic := fun g=>
  A <- evar Type;
  x <- evar A;
  munify g (TheGoal (eq_refl x));; ret nil.

Require Import Unicoq.Unicoq.
Goal forall b : bool, b = b.
MProof.
  mintro b.
  run_tac (bbind (destruct b) [reflexivity; reflexivity]).
Qed.

Definition NotAProduct : Exception. exact exception. Qed.
Program Definition intro (n : string) : tactic := fun g=>
  mmatch g return M list goal with
  | [? (A:Type) (P:A -> Type) e] @TheGoal (forall x:A, P x) e =>
    tnu n (fun x=>
      e' <- evar _;
      g <- abs x e';
      munify e g;;
      new_goal <- abs x (TheGoal e');
      ret [(AHyp new_goal)])
  | _ => raise NotAProduct
  end.

Require Import Bool.Bool.
Goal forall b1 : bool, b1 = b1.
MProof.
  run_tac (bbind (intro "b1") [reflexivity]).
Qed.

Definition idtac : tactic := fun g=>ret [g].

Definition bindb (t u:tactic) : tactic := fun g=>
  l <- t g;
  r <- mmap (open_and_apply u) l;
  let r := simpl List.concat _ r in
  ret r.


Goal forall b1 b2 b3 : bool, b1 && b2 && b3 = b3 && b2 && b1.
MProof.
  run_tac (bindb (intro "b1") (bindb (intro "b2") (intro "b3"))).
  (* something funky with the name of b1 is happening *)
  run_tac (bindb (destruct b1) (bindb (destruct b2) ((bindb (destruct b3) reflexivity)))).
Qed.


Program Definition intro_cont (n:string) (t:tactic) : tactic := fun g=>
  mmatch g return M list goal with
  | [? (A:Type) (P:A -> Type) e] @TheGoal (forall x:A, P x) e =>
    tnu n (fun x=>
      e' <- evar _;
      g <- abs x e';
      munify e g;;
      t (TheGoal e') >> close_goals x)
  | _ => raise NotAProduct
  end.


Class semicolon {A} {B} {C} (t:A) (u:B) := SemiColon { the_value : C }.
Arguments SemiColon {A} {B} {C} t u the_value.

Instance i_intro_cont s t : semicolon (intro s) t | 0 := SemiColon _ _ (intro_cont s t).

Instance i_bbind (t:tactic) (l:list tactic) : semicolon t l :=
  SemiColon _ _ (bbind t l).

Instance i_bindb (t:tactic) (u:tactic) : semicolon t u :=
  SemiColon _ _ (bindb t u).

Instance i_mtac A B (t:M A) (u:M B) : semicolon t u :=
  SemiColon _ _ (_ <- t; u).

Notation "a ;; b" := (@the_value _ _ _ a b _).
(* ;; is in right associativity, but it should be left, right? *)

Goal forall b1 b2 b3 : bool, b1 && b2 && b3 = b3 && b2 && b1.
MProof.
  run_tac (intro "b1" ;; intro "b2" ;; intro "b3").
  run_tac (destruct b1 ;; destruct b2 ;; destruct b3 ;; reflexivity).
Qed.
