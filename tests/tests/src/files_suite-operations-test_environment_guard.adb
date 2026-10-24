separate (Files_Suite.Operations)
   procedure Test_Environment_Guard (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Set_Name   : constant String := "FILES_TEST_GUARD_SET";
      Unset_Name : constant String := "FILES_TEST_GUARD_UNSET";
   begin
      Ada.Environment_Variables.Set (Set_Name, "before");
      Ada.Environment_Variables.Clear (Unset_Name);
      begin
         declare
            Environment : Files_Suite.Support.Environment_Guard;
         begin
            Files_Suite.Support.Save (Environment, Set_Name);
            Files_Suite.Support.Save (Environment, Unset_Name);
            Ada.Environment_Variables.Set (Set_Name, "changed");
            Ada.Environment_Variables.Set (Unset_Name, "created");
            raise Constraint_Error;
         end;
      exception
         when Constraint_Error =>
            null;
      end;
      Assert (Ada.Environment_Variables.Value (Set_Name, "") = "before", "a set variable gets its value back");
      Assert (not Ada.Environment_Variables.Exists (Unset_Name), "an unset variable is unset again");
      Ada.Environment_Variables.Clear (Set_Name);
   end Test_Environment_Guard;
