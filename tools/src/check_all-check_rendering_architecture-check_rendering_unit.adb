separate (Check_All.Check_Rendering_Architecture)
   procedure Check_Rendering_Unit
     (Path  : String;
      Label : String) is
   begin
      Require_Not_Contains_In_Unit
        (Path,
         "with Ada.Directories;",
         Label & " must not import Ada.Directories for filesystem access");
      Require_Not_Contains_In_Unit
        (Path,
         "Ada.Directories.",
         Label & " must not perform filesystem access");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Operations.",
         Label & " must not execute operations");
      --  The qualified forms alone let `use Files.Operations;` and an
      --  unqualified call through; the dependency itself is what is barred.
      Require_Not_Contains_In_Unit
        (Path,
         "with Files.Operations",
         Label & " must not depend on operations");
      Require_Not_Contains_In_Unit
        (Path,
         "with Files.Controller",
         Label & " must not depend on the controller");
      Require_Not_Contains_In_Unit
        (Path,
         "with Files.Application",
         Label & " must not depend on application startup");
      Require_Not_Contains_In_Unit
        (Path,
         "with Files.Interaction",
         Label & " must not depend on the interaction reducer");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Controller.",
         Label & " must not route controller actions");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Application.",
         Label & " must not call application startup logic");
      Require_Not_Contains_In_Unit
        (Path,
         "Execute_Pure_Command",
         Label & " must not dispatch commands");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Commands.Find_By_Shortcut",
         Label & " must not translate input shortcuts");
      Require_Not_Contains_In_Unit
        (Path,
         "with GNAT.OS_Lib;",
         Label & " must not import OS process bindings");
      Require_Not_Contains_In_Unit
        (Path,
         "GNAT.OS_Lib.",
         Label & " must not call OS process bindings");
      Require_Not_Contains_In_Unit
        (Path,
         "GNAT.Expect.",
         Label & " must not call process interaction bindings");
      Require_Not_Contains_In_Unit
        (Path,
         "Create_Process",
         Label & " must not create external processes");
      Require_Not_Contains_In_Unit
        (Path,
         "Spawn",
         Label & " must not spawn external processes");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Settings.Add_Extension_Mapping",
         Label & " must not mutate settings extension mappings");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Settings.Add_Icon_Mapping",
         Label & " must not mutate settings icon mappings");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Settings.Add_Open_Action",
         Label & " must not mutate settings open-action mappings");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Settings.Apply_Draft",
         Label & " must not apply settings drafts");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Settings.Ensure_Default_File",
         Label & " must not create settings files");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Settings.Save_Text",
         Label & " must not write settings text");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Settings.Load_File",
         Label & " must not load settings files");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Set_",
         Label & " must not mutate model state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Begin_",
         Label & " must not mutate model state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Cancel_",
         Label & " must not mutate model state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Clear_",
         Label & " must not mutate model state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Close_",
         Label & " must not mutate model state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Focus_",
         Label & " must not mutate focus state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Go_",
         Label & " must not mutate path history");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Navigate_",
         Label & " must not mutate path history");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Open_",
         Label & " must not mutate model state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Replace_",
         Label & " must not mutate model state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Resume_",
         Label & " must not mutate rename state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Scroll_",
         Label & " must not mutate scroll state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Select_",
         Label & " must not mutate selection state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Move_Selection",
         Label & " must not mutate selection state");
      Require_Not_Contains_In_Unit
        (Path,
         "Files.Model.Toggle_",
         Label & " must not mutate model state");
      --  The concern children hold the same mutators under their own names:
      --  the frame reads the selection, rename fields, history and folder
      --  sizes, and changes none of them.
      for Mutator of Project_Tools.Ada_Source.String_List'
        [To_Unbounded_String ("Files.Model.Selection.Select_"),
         To_Unbounded_String ("Files.Model.Selection.Set_"),
         To_Unbounded_String ("Files.Model.Selection.Clear"),
         To_Unbounded_String ("Files.Model.Selection.Toggle_"),
         To_Unbounded_String ("Files.Model.Selection.Move"),
         To_Unbounded_String ("Files.Model.Selection.Invert"),
         To_Unbounded_String ("Files.Model.Selection.Deselect_"),
         To_Unbounded_String ("Files.Model.Selection.Restore"),
         To_Unbounded_String ("Files.Model.Selection.Reset_"),
         To_Unbounded_String ("Files.Model.Selection.Type_Ahead_Input"),
         To_Unbounded_String ("Files.Model.Rename.Set_"),
         To_Unbounded_String ("Files.Model.Rename.Toggle"),
         To_Unbounded_String ("Files.Model.Rename.Resume"),
         To_Unbounded_String ("Files.Model.Rename.Insert_"),
         To_Unbounded_String ("Files.Model.Rename.Delete"),
         To_Unbounded_String ("Files.Model.Rename.Move_"),
         To_Unbounded_String ("Files.Model.History.Set_"),
         To_Unbounded_String ("Files.Model.History.Begin_"),
         To_Unbounded_String ("Files.Model.History.Commit_"),
         To_Unbounded_String ("Files.Model.History.Merge"),
         To_Unbounded_String ("Files.Model.History.Take_"),
         To_Unbounded_String ("Files.Model.History.Push_"),
         To_Unbounded_String ("Files.Model.History.Release"),
         To_Unbounded_String ("Files.Model.History.Clear_"),
         To_Unbounded_String ("Files.Model.History.Restore"),
         To_Unbounded_String ("Files.Model.Folder_Sizes.Update_"),
         To_Unbounded_String ("Files.Model.Folder_Sizes.Note"),
         To_Unbounded_String ("Files.Model.Folder_Sizes.Clear"),
         To_Unbounded_String ("Files.Model.Folder_Sizes.Prune_"),
         To_Unbounded_String ("Files.Model.Status_Samples.Set_"),
         To_Unbounded_String ("Files.Model.Status_Samples.Note_")]
      loop
         Require_Not_Contains_In_Unit
           (Path,
            To_String (Mutator),
            Label & " must not mutate model state (" & To_String (Mutator) & ")");
      end loop;
      --  The snapshot and frame read nothing from disk: a stat per item
      --  there would run on every rebuild.
      for Banned of Project_Tools.Ada_Source.String_List'
        [To_Unbounded_String ("Hostkit."),
         To_Unbounded_String ("Ada.Text_IO"),
         To_Unbounded_String ("Ada.Streams.Stream_IO"),
         To_Unbounded_String ("Files.IO.Capped_Files"),
         To_Unbounded_String ("Files.IO.Fs_Primitives")]
      loop
         Require_Not_Contains_In_Unit
           (Path,
            To_String (Banned),
            Label & " must not do I/O (" & To_String (Banned) & ")");
      end loop;
   end Check_Rendering_Unit;
