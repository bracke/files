separate (Files_Suite.Operations)
   procedure Test_Paste_Execution_Batches (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "exec-src");
      Dest_Dir : constant String := Join (Root, "exec-dest");
      Count    : constant := 5;
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
      Assert (Files.Model.Paste_Execution_Is_Active (Model), "arming a paste execution activates it");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Paste_Execution_Total (Model),
         Count,
         "the total counts every write action");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Paste_Execution_Done (Model),
         0,
         "nothing is done before the first advance");

      --  Max_Items = 2 over 5 actions => completes after ceil(5 / 2) = 3 calls.
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 2);
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "the first batch reports success");
      Assert (Files.Model.Paste_Execution_Is_Active (Model), "the execution is still in progress after one batch");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Paste_Execution_Done (Model),
         2,
         "the first batch completes two writes");

      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 2);
      Assert (Files.Model.Paste_Execution_Is_Active (Model), "the execution is still in progress after two batches");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Paste_Execution_Done (Model),
         4,
         "progress advances to four writes");

      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 2);
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the third batch finalizes the execution");

      for N in 1 .. Count loop
         Assert (Ada.Directories.Exists (Dest (N)), "every source is copied to the destination");
         Assert (Ada.Directories.Exists (Src (N)), "a copy leaves the sources in place");
      end loop;

      Assert (Files.Model.Undo_Available (Model), "the completed paste records an undo");
      Assert
        (Files.Model.Undo_Kind_Of (Model) = Files.Model.Undo_Delete_Created,
         "a copy paste is undone by deleting the created copies");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Undo_From_Paths (Model).Length),
         Count,
         "one undo covers the whole completed set");

      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Step.Status, Files.Operations.Operation_Success, "undo of the paste succeeds");
      for N in 1 .. Count loop
         Assert (not Ada.Directories.Exists (Dest (N)), "undo removes each pasted copy");
      end loop;
   end Test_Paste_Execution_Batches;
