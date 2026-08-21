--  Compile a restricted regular-expression subset to an NFA and
--  match prefixes.
package Regex_Automata is

   Regex_Error : exception;

   type Engine is private;

   function Compile (Pattern : String) return Engine;
   --  Compile Pattern into an NFA. Raises Regex_Error on invalid syntax.

   function Match_Prefix
     (E     : Engine;
      Input : String;
      From  : Positive) return Natural;
   --  Longest accepting prefix length starting at Input (From).
   --  Returns 0 when there is no match of length at least 1, or when From
   --  is past Input'Last. An empty-string-only match also returns 0.

private

   type State_Index is new Positive;
   type State_Count is new Natural;

   type Transition_Kind is (Epsilon, Char, Class);

   type Char_Set is array (Character) of Boolean;

   type Transition;
   type Transition_Access is access Transition;

   type Transition is record
      Kind   : Transition_Kind := Epsilon;
      Symbol : Character := ASCII.NUL;
      Set    : Char_Set := [others => False];
      Target : State_Index := 1;
      Next   : Transition_Access := null;
   end record;

   type State_Array is array (State_Index range <>) of Transition_Access;
   type State_Array_Access is access State_Array;

   type Engine is record
      Start      : State_Index := 1;
      Accepting  : State_Index := 1;
      State_List : State_Array_Access := null;
   end record;

end Regex_Automata;
