separate (Files_Suite.Operations)
   procedure Test_Paste_Execution_Cancel (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "cancel-src");
      Dest_Dir : constant String := Join (Root, "cancel-dest");
      Count    : constant := 4;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;

      function Img (N : Integer) return String is
      begin
         return Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Both);
      end Img;

      function Src (N : Positive) return String is (Join (Src_Dir, "f" & Img (N) & ".txt"));
      function Dest (N : Positive) return String is (Join (Dest_Dir, "f" & Img (N) & ".txt"));
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      for N in 1 .. Count loop
         Write_File (Src (N), "S" & Img (N));
         Actions.Append
           (Files.Paste.Resolved_Action'
              (Source_Path => To_Unbounded_String (Src (N)),
               Dest_Path   => To_Unbounded_String (Dest (N)),
               Skip        => False,
               Replaced    => False));
      end loop;

      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);

      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 2);
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "the first batch reports success");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Paste_Execution_Done (Model),
         2,
         "two writes complete before cancelling");

      Files.Operations.Cancel_Paste_Execution (Model);
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 2);
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "a cancelled paste finalizes without an error");
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "a cancelled paste finalizes on the next advance");

      Assert (Ada.Directories.Exists (Dest (1)), "the first completed copy is kept");
      Assert (Ada.Directories.Exists (Dest (2)), "the second completed copy is kept");
      Assert (not Ada.Directories.Exists (Dest (3)), "cancelling writes none of the remaining sources");
      Assert (not Ada.Directories.Exists (Dest (4)), "cancelling writes none of the remaining sources");
      for N in 1 .. Count loop
         Assert (Ada.Directories.Exists (Src (N)), "all sources remain after a cancelled copy");
      end loop;

      Assert (Files.Model.Undo_Available (Model), "a cancelled paste still records an undo for completed items");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Undo_From_Paths (Model).Length),
         2,
         "the undo covers only the two completed writes");

      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "undo of the cancelled paste succeeds");
      Assert (not Ada.Directories.Exists (Dest (1)), "undo removes the first completed copy");
      Assert (not Ada.Directories.Exists (Dest (2)), "undo removes the second completed copy");
   end Test_Paste_Execution_Cancel;
