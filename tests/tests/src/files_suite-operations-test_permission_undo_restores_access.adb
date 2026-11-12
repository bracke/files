separate (Files_Suite.Operations)
   --  A permission edit through the editor's path changes only what its bits
   --  concern, and its undo and redo put back the entry's whole access, not
   --  just a mode re-derived from it. On Windows that access is a DACL: the
   --  edit reads back as the mode asked for, keeping every ACE the entry
   --  inherits and its protection where they do not contradict it, and
   --  converting them to explicit ACEs where they do; the undo restores the
   --  DACL it replaced, SDDL for SDDL. On POSIX the mode is the whole of it,
   --  and no record is kept beside it.
   procedure Test_Permission_Undo_Restores_Access (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "access-mode.txt");
      Windows  : constant Boolean := Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.Windows);
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;

      --  The entry's access record as the editor's path reports it: a change
      --  to the mode it already has, which edits nothing.
      function Access_Of (Path : String) return String is
         Previous : Natural;
         Previous_Access, Applied_Access, Identity : Files.Types.UString;
         Mutation : constant Files.File_System.Mutation_Result :=
           Files.File_System.Change_Access
             (Path, "", Mode_Of (Path), "", Previous, Previous_Access, Applied_Access, Identity);
      begin
         Assert (Mutation.Success, "the access of " & Path & " can be read");
         Assert (Previous_Access = Applied_Access, "a change to the mode it has leaves its access alone");
         return To_String (Previous_Access);
      end Access_Of;

      --  How many ACEs an SDDL DACL says were inherited.
      function Inherited (Text : String) return Natural is (Ada.Strings.Fixed.Count (Text, ";ID;"));

      --  Whether an SDDL DACL is protected from inheritance: "D:P...".
      function Is_Protected (Text : String) return Boolean is
        (Text'Length >= 3 and then Text (Text'First .. Text'First + 2) = "D:P");
   begin
      if not Files.File_System.Supports_Permissions then
         Files_Suite.Support.Skip ("Test_Permission_Undo_Restores_Access", "this host has no POSIX permissions to set");
         return;
      end if;

      Reset_Root;
      --  No mode set first: the file keeps the access its folder gave it.
      Write_File (Target, "mode me");
      declare
         Before   : constant Natural := Mode_Of (Target);
         --  Everyone's read bit, turned the other way.
         Edited   : constant Natural := (if (Before / 4) mod 2 = 1 then Before - 4 else Before + 4);
         Original : constant String := Access_Of (Target);
      begin
         if Windows then
            Assert (Inherited (Original) > 0, "the fixture inherits from its folder: " & Original);
         else
            Assert (Original = "", "a POSIX host keeps no access record beside the mode");
         end if;

         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Select_Name (Model, "access-mode.txt");

         Result := Files.Operations.Testing.Set_Permissions_For (Model, Edited, Settings);
         Files_Suite.Support.Assert_Equal
           (Result.Status,
            Files.Operations.Operation_Success,
            "the edit succeeds, " & To_String (Result.Error_Key)
            & (if Result.Status = Files.Operations.Operation_Success then ""
               else Files_Suite.Support.Access_Report (Target)));
         Files_Suite.Support.Assert_Equal (Mode_Of (Target), Edited, "the edit changes the one bit");
         declare
            Changed : constant String := Access_Of (Target);
         begin
            if Windows then
               --  Everyone's read bit turned on gives the group read as well
               --  (it is in Everyone) unless the group is denied it, and
               --  turned off leaves what the folder hands Everyone: either
               --  way what the entry inherits may contradict the edit, and
               --  then the DACL becomes explicit ACEs that do not.
               Assert
                 ((Inherited (Changed) = Inherited (Original) and then Is_Protected (Changed) = Is_Protected (Original))
                  or else (Is_Protected (Changed) and then Inherited (Changed) = 0),
                  "the edit keeps every inherited ACE and the DACL's inheritance, or makes them all explicit: "
                  & Original & " became " & Changed);
            end if;

            Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "the undo succeeds");
            Files_Suite.Support.Assert_Equal (Mode_Of (Target), Before, "the undo restores the mode");
            Assert (Access_Of (Target) = Original, "and the access the edit replaced, exactly: " & Access_Of (Target));

            Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "the redo succeeds");
            Files_Suite.Support.Assert_Equal (Mode_Of (Target), Edited, "the redo re-applies the mode");
            Assert (Access_Of (Target) = Changed, "and the access the edit made, exactly: " & Access_Of (Target));
         end;
      end;
      Reset_Root;
   end Test_Permission_Undo_Restores_Access;
