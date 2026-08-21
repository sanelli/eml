with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;

package body Regex_Automata is

   use Ada.Strings.Unbounded;

   package State_Vectors is new Ada.Containers.Vectors
     (Index_Type   => State_Index,
      Element_Type => Transition_Access);

   type Fragment is record
      Start  : State_Index := 1;
      Finish : State_Index := 1;
   end record;

   type Node_Kind is
     (Lit, Alt, Concat, Star, Plus, Question, Class_Node);

   type Node;
   type Node_Access is access Node;

   type Node is record
      Kind  : Node_Kind := Lit;
      Ch    : Character := ASCII.NUL;
      Set   : Char_Set := [others => False];
      Left  : Node_Access := null;
      Right : Node_Access := null;
   end record;

   procedure Free_Node is new Ada.Unchecked_Deallocation (Node, Node_Access);

   procedure Destroy_Tree (N : in out Node_Access) is
   begin
      if N = null then
         return;
      end if;
      Destroy_Tree (N.Left);
      Destroy_Tree (N.Right);
      Free_Node (N);
   end Destroy_Tree;

   ---------------------------------------------------------------------------
   --  Regex parser
   ---------------------------------------------------------------------------

   type Parser is record
      Pattern : Unbounded_String;
      Pos     : Positive := 1;
      Last    : Natural := 0;
   end record;

   function At_End (P : Parser) return Boolean is
     (P.Pos > P.Last);

   function Peek (P : Parser) return Character is
     (if At_End (P) then ASCII.NUL else Element (P.Pattern, P.Pos));

   procedure Advance (P : in out Parser) is
   begin
      if not At_End (P) then
         P.Pos := P.Pos + 1;
      end if;
   end Advance;

   procedure Fail (Message : String) is
   begin
      raise Regex_Error with Message;
   end Fail;

   function Parse_Escape (P : in out Parser) return Character is
      C : Character;
   begin
      if At_End (P) then
         Fail ("trailing backslash");
      end if;
      C := Peek (P);
      Advance (P);
      case C is
         when '\' | '|' | '(' | ')' | '+' | '*' | '?' | '[' | ']' | '.'
            | '-' | '^' | '$' | '%' | '/' =>
            return C;
         when 't' =>
            return ASCII.HT;
         when 'n' =>
            return ASCII.LF;
         when 'r' =>
            return ASCII.CR;
         when others =>
            Fail ("unsupported escape");
            return ASCII.NUL;
      end case;
   end Parse_Escape;

   function Parse_Class (P : in out Parser) return Char_Set is
      Result    : Char_Set := [others => False];
      Negated   : Boolean := False;
      First     : Boolean := True;
      Have_Prev : Boolean := False;
      Prev      : Character := ASCII.NUL;

      function Next_Char return Character is
         C : Character;
      begin
         if At_End (P) then
            Fail ("unclosed character class");
         end if;
         if Peek (P) = '\' then
            Advance (P);
            C := Parse_Escape (P);
         else
            C := Peek (P);
            Advance (P);
         end if;
         return C;
      end Next_Char;

   begin
      if Peek (P) = '^' then
         Negated := True;
         Advance (P);
      end if;

      while not At_End (P) and then Peek (P) /= ']' loop
         if Have_Prev
           and then Peek (P) = '-'
           and then P.Pos < P.Last
           and then Element (P.Pattern, P.Pos + 1) /= ']'
         then
            Advance (P);
            declare
               Hi : constant Character := Next_Char;
            begin
               if Hi < Prev then
                  Fail ("invalid character range");
               end if;
               for X in Prev .. Hi loop
                  Result (X) := True;
               end loop;
            end;
            Have_Prev := False;
         else
            if Have_Prev then
               Result (Prev) := True;
            end if;
            Prev := Next_Char;
            Have_Prev := True;
         end if;
         First := False;
      end loop;

      if Have_Prev then
         Result (Prev) := True;
      end if;

      if First then
         Fail ("empty character class");
      end if;

      if At_End (P) or else Peek (P) /= ']' then
         Fail ("unclosed character class");
      end if;
      Advance (P);

      if Negated then
         for C in Character loop
            Result (C) := not Result (C);
         end loop;
      end if;
      return Result;
   end Parse_Class;

   function Parse_Alt (P : in out Parser) return Node_Access;

   function Parse_Atom (P : in out Parser) return Node_Access is
      N : Node_Access;
   begin
      if At_End (P) then
         Fail ("unexpected end of pattern");
      end if;

      case Peek (P) is
         when '(' =>
            Advance (P);
            N := Parse_Alt (P);
            if At_End (P) or else Peek (P) /= ')' then
               Fail ("unclosed group");
            end if;
            Advance (P);
            return N;

         when '[' =>
            Advance (P);
            N := new Node'(Kind => Class_Node, others => <>);
            N.Set := Parse_Class (P);
            return N;

         when '\' =>
            Advance (P);
            N := new Node'(Kind => Lit, others => <>);
            N.Ch := Parse_Escape (P);
            return N;

         when ')' | '|' | '*' | '+' | '?' | ']' =>
            Fail ("unexpected metacharacter");
            return null;

         when others =>
            N := new Node'(Kind => Lit, others => <>);
            N.Ch := Peek (P);
            Advance (P);
            return N;
      end case;
   end Parse_Atom;

   function Parse_Piece (P : in out Parser) return Node_Access is
      Atom : constant Node_Access := Parse_Atom (P);
      N    : Node_Access;
   begin
      if not At_End (P) then
         case Peek (P) is
            when '*' =>
               Advance (P);
               N := new Node'(Kind => Star, Left => Atom, others => <>);
               return N;
            when '+' =>
               Advance (P);
               N := new Node'(Kind => Plus, Left => Atom, others => <>);
               return N;
            when '?' =>
               Advance (P);
               N := new Node'(Kind => Question, Left => Atom, others => <>);
               return N;
            when others =>
               null;
         end case;
      end if;
      return Atom;
   end Parse_Piece;

   function Parse_Concat (P : in out Parser) return Node_Access is
      Left : Node_Access := Parse_Piece (P);
      N    : Node_Access;
   begin
      while not At_End (P)
        and then Peek (P) /= ')'
        and then Peek (P) /= '|'
      loop
         N := new Node'
           (Kind  => Concat,
            Left  => Left,
            Right => Parse_Piece (P),
            others => <>);
         Left := N;
      end loop;
      return Left;
   end Parse_Concat;

   function Parse_Alt (P : in out Parser) return Node_Access is
      Left : Node_Access := Parse_Concat (P);
      N    : Node_Access;
   begin
      while not At_End (P) and then Peek (P) = '|' loop
         Advance (P);
         N := new Node'
           (Kind  => Alt,
            Left  => Left,
            Right => Parse_Concat (P),
            others => <>);
         Left := N;
      end loop;
      return Left;
   end Parse_Alt;

   function Parse_Pattern (Pattern : String) return Node_Access is
      P    : Parser :=
        (Pattern => To_Unbounded_String (Pattern),
         Pos     => 1,
         Last    => Pattern'Length);
      Root : Node_Access;
   begin
      if Pattern'Length = 0 then
         Fail ("empty pattern");
      end if;
      Root := Parse_Alt (P);
      if not At_End (P) then
         Fail ("trailing characters in pattern");
      end if;
      return Root;
   end Parse_Pattern;

   ---------------------------------------------------------------------------
   --  Thompson construction
   ---------------------------------------------------------------------------

   function New_State (States : in out State_Vectors.Vector) return State_Index
   is
   begin
      States.Append (null);
      return States.Last_Index;
   end New_State;

   procedure Add_Epsilon
     (States : in out State_Vectors.Vector;
      From   : State_Index;
      Target : State_Index)
   is
      T : constant Transition_Access :=
        new Transition'(Kind => Epsilon, Target => Target, others => <>);
   begin
      T.Next := States (From);
      States (From) := T;
   end Add_Epsilon;

   procedure Add_Char
     (States : in out State_Vectors.Vector;
      From   : State_Index;
      Symbol : Character;
      Target : State_Index)
   is
      T : constant Transition_Access :=
        new Transition'
          (Kind => Char, Symbol => Symbol, Target => Target, others => <>);
   begin
      T.Next := States (From);
      States (From) := T;
   end Add_Char;

   procedure Add_Class
     (States : in out State_Vectors.Vector;
      From   : State_Index;
      Set    : Char_Set;
      Target : State_Index)
   is
      T : constant Transition_Access :=
        new Transition'
          (Kind => Class, Set => Set, Target => Target, others => <>);
   begin
      T.Next := States (From);
      States (From) := T;
   end Add_Class;

   function Build
     (N      : Node_Access;
      States : in out State_Vectors.Vector) return Fragment
   is
      L, R : Fragment;
      S, A : State_Index;
   begin
      case N.Kind is
         when Lit =>
            S := New_State (States);
            A := New_State (States);
            Add_Char (States, S, N.Ch, A);
            return (Start => S, Finish => A);

         when Class_Node =>
            S := New_State (States);
            A := New_State (States);
            Add_Class (States, S, N.Set, A);
            return (Start => S, Finish => A);

         when Concat =>
            L := Build (N.Left, States);
            R := Build (N.Right, States);
            Add_Epsilon (States, L.Finish, R.Start);
            return (Start => L.Start, Finish => R.Finish);

         when Alt =>
            S := New_State (States);
            A := New_State (States);
            L := Build (N.Left, States);
            R := Build (N.Right, States);
            Add_Epsilon (States, S, L.Start);
            Add_Epsilon (States, S, R.Start);
            Add_Epsilon (States, L.Finish, A);
            Add_Epsilon (States, R.Finish, A);
            return (Start => S, Finish => A);

         when Star =>
            S := New_State (States);
            A := New_State (States);
            L := Build (N.Left, States);
            Add_Epsilon (States, S, L.Start);
            Add_Epsilon (States, S, A);
            Add_Epsilon (States, L.Finish, L.Start);
            Add_Epsilon (States, L.Finish, A);
            return (Start => S, Finish => A);

         when Plus =>
            S := New_State (States);
            A := New_State (States);
            L := Build (N.Left, States);
            Add_Epsilon (States, S, L.Start);
            Add_Epsilon (States, L.Finish, L.Start);
            Add_Epsilon (States, L.Finish, A);
            return (Start => S, Finish => A);

         when Question =>
            S := New_State (States);
            A := New_State (States);
            L := Build (N.Left, States);
            Add_Epsilon (States, S, L.Start);
            Add_Epsilon (States, S, A);
            Add_Epsilon (States, L.Finish, A);
            return (Start => S, Finish => A);
      end case;
   end Build;

   function Compile (Pattern : String) return Engine is
      Root   : Node_Access := null;
      States : State_Vectors.Vector;
      Frag   : Fragment;
      Result : Engine;
   begin
      Root := Parse_Pattern (Pattern);
      Frag := Build (Root, States);
      Destroy_Tree (Root);

      Result.Start := Frag.Start;
      Result.Accepting := Frag.Finish;
      Result.State_List :=
        new State_Array
          (States.First_Index .. States.Last_Index);
      for I in Result.State_List'Range loop
         Result.State_List (I) := States (I);
      end loop;
      return Result;
   exception
      when others =>
         Destroy_Tree (Root);
         raise;
   end Compile;

   ---------------------------------------------------------------------------
   --  Matching
   ---------------------------------------------------------------------------

   type Bool_Array is array (State_Index range <>) of Boolean;
   type Bool_Array_Access is access Bool_Array;

   procedure Free_Bool is new Ada.Unchecked_Deallocation
     (Bool_Array, Bool_Array_Access);

   procedure Epsilon_Closure
     (E    : Engine;
      Set  : in out Bool_Array)
   is
      Changed : Boolean := True;
   begin
      while Changed loop
         Changed := False;
         for S in Set'Range loop
            if Set (S) then
               declare
                  T : Transition_Access := E.State_List (S);
               begin
                  while T /= null loop
                     if T.Kind = Epsilon and then not Set (T.Target) then
                        Set (T.Target) := True;
                        Changed := True;
                     end if;
                     T := T.Next;
                  end loop;
               end;
            end if;
         end loop;
      end loop;
   end Epsilon_Closure;

   function Match_Prefix
     (E     : Engine;
      Input : String;
      From  : Positive) return Natural
   is
      Last_State : constant State_Index :=
        (if E.State_List = null then 1 else E.State_List'Last);
      Current    : Bool_Array_Access :=
        new Bool_Array'(1 .. Last_State => False);
      Next_Set   : Bool_Array_Access :=
        new Bool_Array'(1 .. Last_State => False);
      Best       : Natural := 0;
      Pos        : Natural;
   begin
      if E.State_List = null or else From > Input'Last then
         Free_Bool (Current);
         Free_Bool (Next_Set);
         return 0;
      end if;

      Current (E.Start) := True;
      Epsilon_Closure (E, Current.all);
      if Current (E.Accepting) then
         --  Empty match only: treat as no prefix match for tokenizers.
         null;
      end if;

      Pos := From;
      while Pos <= Input'Last loop
         Next_Set.all := [others => False];
         declare
            Moved : Boolean := False;
         begin
            for S in Current'Range loop
               if Current (S) then
                  declare
                     T : Transition_Access := E.State_List (S);
                  begin
                     while T /= null loop
                        case T.Kind is
                           when Char =>
                              if Input (Pos) = T.Symbol then
                                 Next_Set (T.Target) := True;
                                 Moved := True;
                              end if;
                           when Class =>
                              if T.Set (Input (Pos)) then
                                 Next_Set (T.Target) := True;
                                 Moved := True;
                              end if;
                           when Epsilon =>
                              null;
                        end case;
                        T := T.Next;
                     end loop;
                  end;
               end if;
            end loop;

            exit when not Moved;

            Epsilon_Closure (E, Next_Set.all);
            Current.all := Next_Set.all;
            if Current (E.Accepting) then
               Best := Pos - From + 1;
            end if;
            Pos := Pos + 1;
         end;
      end loop;

      Free_Bool (Current);
      Free_Bool (Next_Set);
      return Best;
   end Match_Prefix;

end Regex_Automata;
