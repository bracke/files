with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with AUnit.Simple_Test_Cases;

package body Test_Progress is

   Announce : constant Boolean := Ada.Environment_Variables.Value ("FILES_TEST_PROGRESS", "") /= "";
   --  FILES_TEST_ONLY runs only the routines whose "test : routine" name
   --  contains it, to repeat one under load.
   Only_Text : constant String := Ada.Environment_Variables.Value ("FILES_TEST_ONLY", "");

   --  AUnit asks twice a routine; name each once.
   Last : Ada.Strings.Unbounded.Unbounded_String;

   --  The last routine counted as matching, for the same reason.
   Last_Matched : Ada.Strings.Unbounded.Unbounded_String;
   Match_Count  : Natural := 0;

   function Only return String is (Only_Text);

   function Matched return Natural is (Match_Count);

   overriding function Is_Active
     (Filter : Progress_Filter;
      T      : AUnit.Tests.Test'Class)
      return Boolean
   is
      pragma Unreferenced (Filter);
      use type AUnit.Message_String;
   begin
      if (Announce or else Only_Text /= "") and then T in AUnit.Simple_Test_Cases.Test_Case'Class then
         declare
            Item    : AUnit.Simple_Test_Cases.Test_Case'Class renames AUnit.Simple_Test_Cases.Test_Case'Class (T);
            Name    : constant AUnit.Message_String := AUnit.Simple_Test_Cases.Name (Item);
            Routine : constant AUnit.Message_String := AUnit.Simple_Test_Cases.Routine_Name (Item);
            Line    : constant String :=
              "RUN " & (if Name = null then "?" else Name.all)
              & (if Routine = null then "" else " : " & Routine.all);
            use type Ada.Strings.Unbounded.Unbounded_String;
         begin
            if Only_Text /= "" then
               if Ada.Strings.Fixed.Index (Line, Only_Text) = 0 then
                  return False;
               end if;
               if Last_Matched /= Line then
                  Last_Matched := Ada.Strings.Unbounded.To_Unbounded_String (Line);
                  Match_Count := Match_Count + 1;
               end if;
            end if;
            if Announce and then Last /= Line then
               Last := Ada.Strings.Unbounded.To_Unbounded_String (Line);
               Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Line);
               Ada.Text_IO.Flush (Ada.Text_IO.Standard_Error);
            end if;
         end;
      end if;
      return True;
   end Is_Active;

end Test_Progress;
