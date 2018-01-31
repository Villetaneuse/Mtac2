val isret : EConstr.t -> bool
val isbind : EConstr.t -> bool
val istry' : EConstr.t -> bool
val israise : EConstr.t -> bool
val isfix1 : EConstr.t -> bool
val isfix2 : EConstr.t -> bool
val isfix3 : EConstr.t -> bool
val isfix4 : EConstr.t -> bool
val isfix5 : EConstr.t -> bool
val isis_var : EConstr.t -> bool
val isnu : EConstr.t -> bool
val isabs_fun : EConstr.t -> bool
val isabs_let : EConstr.t -> bool
val isabs_prod_prop : EConstr.t -> bool
val isabs_prod_type : EConstr.t -> bool
val isabs_fix : EConstr.t -> bool
val isget_binder_name : EConstr.t -> bool
val isremove : EConstr.t -> bool
val isgen_evar : EConstr.t -> bool
val isis_evar : EConstr.t -> bool
val ishash : EConstr.t -> bool
val issolve_typeclasses : EConstr.t -> bool
val isprint : EConstr.t -> bool
val ispretty_print : EConstr.t -> bool
val ishyps : EConstr.t -> bool
val isdestcase : EConstr.t -> bool
val isconstrs : EConstr.t -> bool
val ismakecase : EConstr.t -> bool
val isunify : EConstr.t -> bool
val isunify_univ : EConstr.t -> bool
val isget_reference : EConstr.t -> bool
val isget_var : EConstr.t -> bool
val iscall_ltac : EConstr.t -> bool
val islist_ltac : EConstr.t -> bool
val isread_line : EConstr.t -> bool
val isbreak : EConstr.t -> bool
val isdecompose : EConstr.t -> bool
val issolve_typeclass : EConstr.t -> bool
val isdeclare : EConstr.t -> bool
val isdeclare_implicits : EConstr.t -> bool
val isos_cmd : EConstr.t -> bool
val isget_debug_ex : EConstr.t -> bool
val isset_debug_ex : EConstr.t -> bool
val isget_trace : EConstr.t -> bool
val isset_trace : EConstr.t -> bool
val isdecompose_app : EConstr.t -> bool
val isnew_timer : EConstr.t -> bool
val isstart_timer : EConstr.t -> bool
val isstop_timer : EConstr.t -> bool
val isreset_timer : EConstr.t -> bool
val isprint_timer : EConstr.t -> bool
