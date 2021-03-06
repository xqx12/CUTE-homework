open Types

exception Misprediction
exception Completed

let negateRop = function
    LT -> GE
  | LE -> GT
  | GT -> LE
  | GE -> LT
  | EQ -> NEQ
  | NEQ -> EQ

let negate = function
  | Predicate (rop, s1, s2) -> Predicate (negateRop rop, s1, s2)
  | Constant b -> Constant (not b)


let cond_no = Parser.cond_no

let make_path_c () = 
  Array.make !cond_no (Constant true)

let addPathConstraint path_c k predicate = 
  try 
    path_c.(k) <- predicate
  with 
      Invalid_argument _ ->
        Printf.printf "(addPathConstraint, Index out bounds, %d)\n" k;
        exit 2

type conditional = 
  {
    id            : int;
    mutable taken : bool;
    mutable done_ : bool
  }
  
let dummy_cond = { id = -1; taken = false; done_ = false}

let top = ref 0

let make_stack () = Array.make !cond_no dummy_cond

let init_stack infile stack = 
  top := 0;
  try 
    while true do
      let (id, taken, done_) = 
        Scanf.fscanf infile "(%d, %B, %B)\n" (fun i t d -> (i,t,d)) 
      in
      stack.(!top) <- {id = id ; taken = taken; done_ = done_};
      incr top
    done
  with End_of_file -> ()

let output_stack stack j outfile =
  for i = 0 to j do
    Printf.fprintf outfile "(%d, %B, %B)\n" 
        stack.(i).id stack.(i).taken stack.(i).done_;
  done


let add_to_stack stack c =
  stack.(!top) <- c;
  incr top

let compare_and_update_stack stack id taken k = 
  if (k < !top) then
    begin 
      if (stack.(k).taken <> taken)
      then raise Misprediction
      else 
        if (k = !top - 1) then 
          stack.(k).done_ <- true
    end
  else
    let c = 
      { 
        id = id;
        taken = taken;
        done_ = false
      }
    in
      add_to_stack stack c
      
let rec solve_path_constraint path_c stack k symVars = 
  let rec choose_cond i =
    if (i = -1) then i
    else 
      if stack.(i).done_ then choose_cond (i-1)
      else i
  in
  let j = choose_cond (k-1) in 
  if (j = -1) then
    raise Completed
  else 
  	begin
      path_c.(j) <- negate path_c.(j);
      stack.(j).taken <- not (stack.(j).taken);
      match Solver.solve j path_c symVars with 
        | Some sol ->
          (sol, j)
        | None ->
          solve_path_constraint path_c stack j symVars
     end

