separate (Files_Suite.Operations)
   procedure Test_Backslash_Executable_Lookup (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         declare
            Tool : constant String := Join (Root, "tool\name");
            Old_Path_Exists : constant Boolean :=
              Ada.Environment_Variables.Exists ("PATH");
            Old_Path : constant String :=
              (if Old_Path_Exists
               then Ada.Environment_Variables.Value ("PATH")
               else "");
            Action : constant Files.Settings.Open_Action :=
              Files.Settings.Make_Action
                ("tool\name", Files.Types.String_Vectors.Empty_Vector);
            Available : Boolean := False;
         begin
            Write_File (Tool, "#!/bin/sh" & ASCII.LF & "exit 0" & ASCII.LF);
            Mutation := Files.File_System.Set_Permissions (Tool, 8#755#);
            if Mutation.Success then
               Ada.Environment_Variables.Set ("PATH", Root);
               Available :=
                 Files.Operations.Open_Action_Executable_Is_Available (Action);
               if Old_Path_Exists then
                  Ada.Environment_Variables.Set ("PATH", Old_Path);
               else
                  Ada.Environment_Variables.Clear ("PATH");
               end if;
               Assert
                 (Available,
                  "a POSIX executable containing a backslash is looked up on PATH");
            end if;
         exception
            when others =>
               if Old_Path_Exists then
                  Ada.Environment_Variables.Set ("PATH", Old_Path);
               else
                  Ada.Environment_Variables.Clear ("PATH");
               end if;
               raise;
         end;
      end if;
   end Test_Backslash_Executable_Lookup;
