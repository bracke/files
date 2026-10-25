separate (Files_Suite.Operations)
   procedure Test_Paste_Execution_Small_Op (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "small-src");
      Dest_Dir : constant String := Join (Root, "small-dest");
      Source   : constant String := Join (Src_Dir, "only.txt");
      Dest     : constant String := Join (Dest_Dir, "only.txt");
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Source, "ONLY");
      Actions.Append
        (Files.Paste.Resolved_Action'
           (Source_Path => To_Unbounded_String (Source),
            Dest_Path   => To_Unbounded_String (Dest),
            Skip        => False,
            Replaced    => False));

      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);

      --  A single-item paste finishes within the first advance and leaves no
      --  lingering execution state (so no progress overlay is ever shown).
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 8);
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "the one-item paste reports success");
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the one-item paste clears its execution state");
      Assert (Ada.Directories.Exists (Dest), "the one item is copied to the destination");
   end Test_Paste_Execution_Small_Op;
