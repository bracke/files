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
         "Files.Commands.Execution",
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
      --  The snapshot and frame read nothing from disk: a stat per item
      --  there would run on every rebuild.
      for Banned of Project_Tools.Ada_Source.String_List'
        [To_Unbounded_String ("Hostkit."),
         To_Unbounded_String ("Ada.Text_IO"),
         To_Unbounded_String ("Ada.Streams.Stream_IO"),
         To_Unbounded_String ("Files.Capped_Files"),
         To_Unbounded_String ("Files.Fs_Primitives")]
      loop
         Require_Not_Contains_In_Unit
           (Path,
            To_String (Banned),
            Label & " must not do I/O (" & To_String (Banned) & ")");
      end loop;
   end Check_Rendering_Unit;
