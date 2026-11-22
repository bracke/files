separate (Check_All)
   procedure Check_Event_Translation_Contract is
      Events_Spec : constant String := Root & "/src/files-events.ads";
      Events_Body : constant String := Root & "/src/files-events.adb";

      --  Of files' own units, translation may only import the pure
      --  Files.Rendering.Hit and Files.Rendering.Layouts geometry and the
      --  value types its actions carry, which forbids the mutable model, filesystem-operation, and
      --  filesystem-inspection units.
      Body_Allowed : constant String_List :=
        [To_Unbounded_String ("Files.Rendering.Hit"),
         To_Unbounded_String ("Files.Rendering.Layouts"),
         To_Unbounded_String ("Files.Rendering.Layouts.Details"),
         To_Unbounded_String ("Files.Rendering.Layouts.Dialogs"),
         To_Unbounded_String ("Files.Rendering.Layouts.Menus"),
         To_Unbounded_String ("Files.Rendering.Layouts.Tree"),
         --  The value types the actions carry (command ids, item and focus
         --  values), read only: the checks below forbid executing a command.
         To_Unbounded_String ("Files.Commands"),
         --  Which commands an overlay's own controls run: a constant table.
         To_Unbounded_String ("Files.Commands.Overlay_Buttons"),
         To_Unbounded_String ("Files.Preference_Types"),
         To_Unbounded_String ("Files.Types"),
         To_Unbounded_String ("Files.UI_Types")];

      --  Nor does it bind to foreign code itself: no import, export or
      --  machine-level representation.
      Foreign_Tokens : constant String_List :=
        [To_Unbounded_String ("Import"),
         To_Unbounded_String ("Export"),
         To_Unbounded_String ("Convention"),
         To_Unbounded_String ("External_Name"),
         To_Unbounded_String ("Link_Name"),
         To_Unbounded_String ("Address")];

      --  Reject a with of any Filesystem_Units unit in Path.
      --
      --  @param Path An Ada source of Files.Events.
      procedure Require_No_Filesystem_Imports (Path : String) is
      begin
         for Unit of Filesystem_Units loop
            Require_Only_Allowed_With_Clauses (Path, To_String (Unit), No_Units);
         end loop;
      exception
         when Program_Error =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "error: event translation must not import filesystem or process units: " & Path);
            raise;
      end Require_No_Filesystem_Imports;

      --  Apply the body's with-clause boundary to every subunit of
      --  Files.Events (files-events-*.adb, nested subunits included): a
      --  subunit inherits the body's context and may add its own with
      --  clauses, which would otherwise widen the boundary unseen.
      procedure Check_Subunit_With_Clauses is
      begin
         for Item of Project_Tools.Files.List_Tree (Root & "/src", "files-events-*.adb", Generated_Directories) loop
            declare
               procedure No_Foreign_Tokens is
               begin
                  Project_Tools.Ada_Source.Require_No_Code_Tokens (To_String (Item), Foreign_Tokens);
               end No_Foreign_Tokens;
            begin
               Require_Only_Allowed_With_Clauses (To_String (Item), "Files.", Body_Allowed);
               Require_No_Filesystem_Imports (To_String (Item));
               Guarded (No_Foreign_Tokens'Access);
            end;
         end loop;
      end Check_Subunit_With_Clauses;
   begin
      --  No filesystem or process imports in the spec, the body, or (below)
      --  any subunit.
      Require_No_Filesystem_Imports (Events_Spec);
      Require_No_Filesystem_Imports (Events_Body);
      --  Lock the Files.* import boundary through the shared helper, over the
      --  body and every subunit.
      Require_Only_Allowed_With_Clauses (Events_Body, "Files.", Body_Allowed);
      Check_Subunit_With_Clauses;
      --  The spec names the types translation reads and produces: the input
      --  actions (Files.Input_Actions, which re-exports them) and the
      --  View_Snapshot and Frame_Commands that Translate_Click hit-tests
      --  (Files.Rendering). Those are allowed there and nothing else -- the
      --  body checks below still forbid any call into them beyond reading
      --  those values.
      Require_Only_Allowed_With_Clauses
        (Events_Spec,
         "Files.",
         [To_Unbounded_String ("Files.Input_Actions"),
          To_Unbounded_String ("Files.Rendering")]);
      --  The controller applies input actions (Files.Input_Actions) without
      --  depending on their translation, nor through it on the rendering
      --  snapshot: no controller unit names Files.Events.
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "files-controller*.ad?", Generated_Directories) loop
         Require_Only_Allowed_With_Clauses (To_String (Item), "Files.Events", No_Units);
      end loop;
      Require_Not_Contains
        (Events_Spec,
         "Files.Model.",
         "event translation's spec must not name live model state");
      Require_Not_Contains
        (Events_Spec,
         "Files.File_System.",
         "event translation's spec must not name filesystem state");
      Require_Not_Contains
        (Events_Spec,
         "Files.Operations.",
         "event translation's spec must not name operation execution");
      Require_Not_Contains_In_Unit
        (Events_Body,
         "Execute_Pure_Command",
         "event translation must not directly execute commands");
      Require_Not_Contains_In_Unit
        (Events_Body,
         "Files.Operations.",
         "event translation must not route through operation execution");
      Require_Not_Contains_In_Unit
        (Events_Body,
         "Files.File_System.",
         "event translation must not inspect or mutate the filesystem");
      Require_Not_Contains_In_Unit
        (Events_Body,
         "Files.Model.",
         "event translation must not mutate or inspect live model state");

      --  The model holds its background jobs' handles as data; starting,
      --  polling, cancelling and stepping them is Files.Operations' work. So
      --  model code names only the handle type and the queries below.
      for Job_Package of String_List'
        [To_Unbounded_String ("Files.Transfer_Jobs"),
         To_Unbounded_String ("Files.Jobs.Process"),
         To_Unbounded_String ("Files.Folder_Size")]
      loop
         Require_Only_Names_From
           ("files-model",
            To_String (Job_Package),
            [To_Unbounded_String ("Session"),
             To_Unbounded_String ("Active"),
             To_Unbounded_String ("Is_Active"),
             To_Unbounded_String ("Target_For_Test"),
             To_Unbounded_String ("Path_Vectors"),
             --  Finished measurements handed to the model, and the stale ones
             --  it hands back: data, not a job.
             To_Unbounded_String ("Measurement"),
             To_Unbounded_String ("Measurement_Vectors")],
            "the model drives no background job");
      end loop;

      --  The model reads no disk: what it shows was read by an operation or
      --  a job, so it can be rebuilt and tested without one. Names a model
      --  unit may take from the packages that do I/O are the pure ones.
      Require_Only_Names_From
        ("files-model", "Files.Settings",
         [To_Unbounded_String ("Settings_Model"),
          To_Unbounded_String ("Settings_Draft"),
          --  Pairs a draft's mapping lists up, in memory.
          To_Unbounded_String ("Normalize_Draft"),
          To_Unbounded_String ("Path_Label_Vectors"),
          To_Unbounded_String ("Path_References"),
          --  Copies the two classification maps out of a settings model.
          To_Unbounded_String ("Classification_Of")],
         "the model reads no disk (settings are loaded and saved elsewhere)",
         --  Settings is also what the model's parameters are called.
         Short_Too => False);
      --  The labels it groups by, and the recent list whose order the Recent
      --  view returns to when a grouping ends, read; changing them is the
      --  settings' own.
      Require_Only_Names_From
        ("files-model", "Files.Settings.Path_References",
         [To_Unbounded_String ("Path_Labels"),
          To_Unbounded_String ("Same_Labels"),
          To_Unbounded_String ("Recent_Paths")],
         "the model only reads the stored labels and recent list");
      Require_Only_Names_From
        ("files-model", "Files.Desktop_Applications",
         [To_Unbounded_String ("Application_Vectors")],
         "the model reads no disk (applications are listed elsewhere)",
         Short_Too => False);
      Require_Only_Names_From
        ("files-model", "Ada.Directories", [To_Unbounded_String ("Simple_Name")],
         "the model reads no disk");
      Require_Only_Names_From
        ("files-model", "GNAT.OS_Lib", [To_Unbounded_String ("Is_Absolute_Path")],
         "the model reads no disk");
      for Banned of String_List'
        [To_Unbounded_String ("Hostkit."),
         To_Unbounded_String ("Ada.Text_IO"),
         To_Unbounded_String ("Ada.Streams.Stream_IO"),
         To_Unbounded_String ("Files.IO.Capped_Files"),
         To_Unbounded_String ("Files.IO.Fs_Primitives")]
      loop
         Require_Not_Contains_In_Unit
           (Root & "/src/files-model.adb",
            To_String (Banned),
            "the model reads no disk (" & To_String (Banned) & ")");
         Require_Not_Contains
           (Root & "/src/files-model.ads",
            To_String (Banned),
            "the model reads no disk (" & To_String (Banned) & ")");
      end loop;
      --  A deny-list misses a new way to the disk (it went through
      --  Copy_Context, which makes a transport): every files-model* unit
      --  may import only these. A new import is a decision made here.
      Require_Only_Names_From
        ("files-model", "Files.Jobs.Copy_Context",
         [To_Unbounded_String ("Session"), To_Unbounded_String ("Empty_Session"), To_Unbounded_String ("Valid")],
         "the model makes no transport; Operations.Begin_Paste_Execution does");
      declare
         --  Files.Commands: the command a palette row names, the
         --  registry's ids, read.
         Allowed : constant String_List :=
           [To_Unbounded_String ("Files.Commands"),
            To_Unbounded_String ("Files.Desktop_Applications"),
            --  A handler's trace of what it carried on past, not model I/O.
            To_Unbounded_String ("Files.Diagnostics"),
            --  The info pane's extra line as data: the model only keeps it.
            To_Unbounded_String ("Files.Extra_Info"),
            --  The filesystem layer's value types alone, no I/O: what the
            --  model's spec holds of it.
            To_Unbounded_String ("Files.File_System_Types"),
            To_Unbounded_String ("Files.File_Types"),
            To_Unbounded_String ("Files.Folder_Size"),
            To_Unbounded_String ("Files.Folder_Tree"),
            To_Unbounded_String ("Files.Grouping"),
            --  Items built from a name and sorted, reading no disk.
            To_Unbounded_String ("Files.Item_Lists"),
            To_Unbounded_String ("Files.Items"),
            To_Unbounded_String ("Files.Jobs.Copy_Context"),
            To_Unbounded_String ("Files.Jobs.Process"),
            To_Unbounded_String ("Files.Model.Support"),
            --  A leaf name's stem and extension, from its text alone.
            To_Unbounded_String ("Files.Name_Parts"),
            To_Unbounded_String ("Files.Paste"),
            --  The paste prompt's and run's state as values (no I/O).
            To_Unbounded_String ("Files.Paste_States"),
            To_Unbounded_String ("Files.Path_Checks"),
            --  The view preferences' value types.
            To_Unbounded_String ("Files.Preference_Types"),
            To_Unbounded_String ("Files.Quick_Look"),
            To_Unbounded_String ("Files.Settings"),
            To_Unbounded_String ("Files.Settings.Path_References"),
            --  Text helpers (counts, prefixes, case folding), no I/O.
            To_Unbounded_String ("Files.Text_Basics"),
            To_Unbounded_String ("Files.Text_Case"),
            To_Unbounded_String ("Files.Model.Selection.Type_Ahead"),
            To_Unbounded_String ("Files.Types"),
            To_Unbounded_String ("Files.UI_Types"),
            --  The undo history's values (no I/O): the model holds a history.
            To_Unbounded_String ("Files.Undo.History"),
            To_Unbounded_String ("Files.Undo.Payloads")];
      begin
         for Item of Project_Tools.Files.List_Tree (Root & "/src", "files-model*.ad?", Generated_Directories) loop
            Require_Only_Allowed_With_Clauses (To_String (Item), "Files.", Allowed);
            --  Nor any unit that does I/O, however it is spelled: a deny-list
            --  of a few names let GNAT.Directory_Operations or a C import
            --  through. Ada.Directories is held to Simple_Name above.
            for Unit of Filesystem_Units loop
               if To_String (Unit) /= "Ada.Directories" then
                  Require_Only_Allowed_With_Clauses (To_String (Item), To_String (Unit), No_Units);
               end if;
            end loop;
         end loop;
      end;
      --  The model holds the filesystem layer's values through their leaf
      --  package only, in its spec (so the whole filesystem layer is not a
      --  dependency of every unit that names a window model) and in every
      --  body: the items it sorts and the placeholders it builds come from
      --  Files.Items, which touches no disk.
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "files-model*.ad?", Generated_Directories) loop
         Require_Only_Allowed_With_Clauses
           (To_String (Item), "Files.File_System",
            [To_Unbounded_String ("Files.File_System_Types")]);
      end loop;
   end Check_Event_Translation_Contract;
