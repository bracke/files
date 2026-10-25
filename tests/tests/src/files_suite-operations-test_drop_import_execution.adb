separate (Files_Suite.Operations)
   procedure Test_Drop_Import_Execution (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Sources  : Files.Types.String_Vectors.Vector;
      Plans    : Files.File_System.Drop_Import_Result;
      Mutation : Files.File_System.Mutation_Result;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Source_File : constant String := Join (Root, "drop-source.txt");
      Source_Dir  : constant String := Join (Root, "drop-dir");
      Drop_Target : constant String := Join (Root, "drop-target");
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Drop_Target);
      Write_File (Source_File, "drop");
      Ada.Directories.Create_Path (Source_Dir);
      Write_File (Join (Source_Dir, "inside.txt"), "inside");
      Sources.Append (To_Unbounded_String (Source_File));
      Sources.Append (To_Unbounded_String (Source_Dir));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Drop_Target);
      Assert (Plans.Success, "drop import planning accepts valid dropped paths");
      Files_Suite.Support.Assert_Equal (Natural (Plans.Plans.Length), 2, "drop import plans every source path");
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "drop import copy executes");
      Assert (Ada.Directories.Exists (Join (Drop_Target, "drop-source.txt")), "drop import copies files");
      Assert
        (Ada.Directories.Exists (Join (Join (Drop_Target, "drop-dir"), "inside.txt")),
         "drop import copies directories");
      Assert (Ada.Directories.Exists (Source_File), "drop copy preserves source file");

      Load := Files.File_System.Load_Directory (Drop_Target, Settings);
      Files.Model.Initialize (Model, Drop_Target, Load.Items, Root);
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Source_File));
      --  Dropping onto a name that already exists now arms the paste conflict
      --  dialog (routed through the engine) instead of silently auto-renaming.
      Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "controller drop import succeeds");
      Assert
        (Files.Model.Paste_Conflict_Is_Active (Model),
         "a colliding drop arms the conflict dialog instead of auto-renaming");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Paste_Conflict_Name (Model),
         "drop-source.txt",
         "the drop conflict dialog names the colliding item");
      Routed.Operation :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Rename, False);
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "resolving the drop conflict clears the dialog");
      Assert
        (Ada.Directories.Exists (Join (Drop_Target, "drop-source 2.txt")),
         "renaming the drop conflict writes a collision-safe destination");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         3,
         "resolved drop import refreshes destination model");

      Ada.Directories.Create_Path (Join (Drop_Target, "nested-target"));
      Write_File (Join (Drop_Target, "drag-source.txt"), "drag");
      Load := Files.File_System.Load_Directory (Drop_Target, Settings);
      Files.Model.Initialize (Model, Drop_Target, Load.Items, Root);
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Drop_Target, "drag-source.txt")));
      --  A drop onto a specific folder row routes through Begin_Paste_To; with
      --  no name collision it executes the move immediately.
      Routed.Operation :=
        Files.Operations.Begin_Paste_To
          (Model          => Model,
           Settings       => Settings,
           Source_Paths   => Sources,
           Destination    => Join (Drop_Target, "nested-target"),
           Mode           => Files.File_System.Drop_Move,
           From_Clipboard => False);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "item drag import can target a specific directory");
      Assert
        (not Files.Model.Paste_Conflict_Is_Active (Model),
         "a collision-free targeted drop executes without arming the dialog");
      Assert
        (Ada.Directories.Exists (Join (Join (Drop_Target, "nested-target"), "drag-source.txt")),
         "item drag import moves the source into the target directory");
      Assert
        (not Ada.Directories.Exists (Join (Drop_Target, "drag-source.txt")),
         "item drag move removes the source from the current directory");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         4,
         "item drag import refreshes the source window model");

      Sources.Clear;
      Write_File (Join (Root, "move-source.txt"), "move");
      Sources.Append (To_Unbounded_String (Join (Root, "move-source.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Drop_Target, Files.File_System.Drop_Move);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "drop import move executes");
      Assert (Ada.Directories.Exists (Join (Drop_Target, "move-source.txt")), "drop move creates destination");
      Assert (not Ada.Directories.Exists (Join (Root, "move-source.txt")), "drop move removes source");
   end Test_Drop_Import_Execution;
