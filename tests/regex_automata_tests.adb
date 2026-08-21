with Ada.Text_IO;

with Regex_Automata;

package body Regex_Automata_Tests is

   procedure Run (Failed : in out Boolean) is

      procedure Require (Cond : Boolean; Message : String) is
      begin
         if not Cond then
            Failed := True;
            Ada.Text_IO.Put_Line ("FAIL: " & Message);
         end if;
      end Require;

      procedure Expect_Match
        (Pattern : String;
         Input   : String;
         From    : Positive;
         Length  : Natural;
         Label   : String)
      is
         E : constant Regex_Automata.Engine :=
           Regex_Automata.Compile (Pattern);
         Got : constant Natural :=
           Regex_Automata.Match_Prefix (E, Input, From);
      begin
         Require
           (Got = Length,
            Label
            & ": expected "
            & Natural'Image (Length)
            & " got "
            & Natural'Image (Got));
      end Expect_Match;

   begin
      Expect_Match ("a", "a", 1, 1, "literal");
      Expect_Match ("abc", "abcdef", 1, 3, "concat");
      Expect_Match ("a|b", "b", 1, 1, "alt");
      Expect_Match ("a*", "aaab", 1, 3, "star");
      Expect_Match ("a+", "aaab", 1, 3, "plus");
      Expect_Match ("a?", "b", 1, 0, "question-empty-is-zero");
      Expect_Match ("a?", "a", 1, 1, "question");
      Expect_Match ("(ab)+", "ababx", 1, 4, "group-plus");
      Expect_Match ("[a]", "a", 1, 1, "class-single");
      Expect_Match ("[abc]", "b", 1, 1, "class-list");
      Expect_Match ("[0-9]", "4", 1, 1, "class-digit");
      Expect_Match ("[0-9]+", "42x", 1, 2, "class-range");
      Expect_Match ("[^0-9]", "a1", 1, 1, "negated-class");
      Expect_Match ("\+", "+", 1, 1, "escaped-plus");
      Expect_Match ("a+", "xaaab", 2, 3, "from-offset");

      Expect_Match ("abc", "ab", 1, 0, "no-match");
      Expect_Match ("a+", "", 1, 0, "empty-input");

      declare
         Raised : Boolean := False;
      begin
         declare
            E : Regex_Automata.Engine;
            pragma Unreferenced (E);
         begin
            E := Regex_Automata.Compile ("(unclosed");
         exception
            when Regex_Automata.Regex_Error =>
               Raised := True;
         end;
         Require (Raised, "invalid-pattern-unclosed");
      end;

      declare
         Raised : Boolean := False;
      begin
         declare
            E : Regex_Automata.Engine;
            pragma Unreferenced (E);
         begin
            E := Regex_Automata.Compile ("\q");
         exception
            when Regex_Automata.Regex_Error =>
               Raised := True;
         end;
         Require (Raised, "invalid-escape");
      end;

      declare
         Raised : Boolean := False;
      begin
         declare
            E : Regex_Automata.Engine;
            pragma Unreferenced (E);
         begin
            E := Regex_Automata.Compile ("[]");
         exception
            when Regex_Automata.Regex_Error =>
               Raised := True;
         end;
         Require (Raised, "empty-class");
      end;
   end Run;

end Regex_Automata_Tests;
