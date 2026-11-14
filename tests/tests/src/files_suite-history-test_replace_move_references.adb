with Files.Foreground_Jobs;
with Files.Interaction;
with Files.Settings.Path_References;
with Files_Suite.Support.Guards;
separate (Files_Suite.History)
   --  A move that replaced an existing item left the replaced item's label,
   --  favorite and recent entry on the path, beside the moved item's own:
   --  two labels, two favorites, two recent entries for one path, the
   --  replaced item's label winning. The replaced item's references now go
   --  with it to its recovery stage, and come back with it on Undo.
   procedure Test_Replace_Move_References (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Color_Label;
      Settings    : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home  : constant String := Root & "_references_xdg";
      Src_Dir     : constant String := Join (Root, "references-src");
      Dest_Dir    : constant String := Join (Root, "references-dest");
      Source      : constant String := Join (Src_Dir, "report.txt");
      Dest        : constant String := Join (Dest_Dir, "report.txt");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;
      Actions     : Files.Paste.Resolved_Action_Vectors.Vector;
      Load        : Files.File_System.Directory_Load_Result;
      Model       : aliased Files.Model.Window_Model;
      Paste       : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Step        : Files.Operations.Operation_Result;
      Followed    : Boolean;

      --  How often List holds Path.
      function Count (List : Files.Types.String_Vectors.Vector; Path : String) return Natural is
         Result : Natural := 0;
      begin
         for Item of List loop
            if To_String (Item) = Path then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Count;

      --  How many labels Path has.
      function Labels (Path : String) return Natural is
         Result : Natural := 0;
      begin
         for Item of Settings.Labels loop
            if To_String (Item.Path) = Path then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Labels;

      --  Path is labelled Label once, a favorite once and recent once.
      procedure Assert_Once (Path : String; Label : Files.Types.Color_Label; What : String) is
      begin
         Assert (Files.Settings.Path_References.Label_Of (Settings, Path) = Label and then Labels (Path) = 1,
                 What & " has its own label, once:" & Labels (Path)'Image);
         Files_Suite.Support.Assert_Equal (Count (Settings.Favorite_Paths, Path), 1, What & " is a favorite once");
         Files_Suite.Support.Assert_Equal
           (Count (Files.Settings.Path_References.Recent_Paths (Settings), Path), 1, What & " is recent once");
      end Assert_Once;
   begin
      Files_Suite.Support.Guards.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Guards.Save (Environment, "HOME");
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Source, "new");
      Write_File (Dest, "old");
      Files.Settings.Path_References.Set_Label (Settings, Source, Files.Types.Blue);
      Files.Settings.Path_References.Set_Label (Settings, Dest, Files.Types.Red);
      Files.Settings.Path_References.Toggle_Favorite_Path (Settings, Source);
      Files.Settings.Path_References.Toggle_Favorite_Path (Settings, Dest);
      Files.Settings.Path_References.Note_Recent (Settings, Dest);
      Files.Settings.Path_References.Note_Recent (Settings, Source);

      --  Move report.txt over the one at the destination.
      Actions.Append
        (Files.Paste.Resolved_Action'
           (Source_Path => To_Unbounded_String (Source),
            Dest_Path   => To_Unbounded_String (Dest),
            Skip        => False,
            Replaced    => True));
      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Operations.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move);
      Step := Files.Foreground_Jobs.Advance (Model, Settings, 8);
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operations.Operation_Success, "the move-replace paste succeeds");
      Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
      Assert (Followed, "the move changes the settings");
      Assert_Once (Dest, Files.Types.Blue, "the moved item at its new path");
      Assert (Files.Settings.Path_References.Label_Of (Settings, Source) = Files.Types.No_Label
              and then not Files.Settings.Path_References.Is_Favorite (Settings, Source)
              and then Count (Files.Settings.Path_References.Recent_Paths (Settings), Source) = 0,
              "nothing is left at the moved item's old path");
      Files_Suite.Support.Assert_Equal (Natural (Settings.Labels.Length), 2, "the replaced item keeps its label");

      --  Undo puts both back, each with its own.
      Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operations.Operation_Success, "the move-replace is undone");
      Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
      Assert (Followed, "the undo changes the settings");
      Assert_Once (Source, Files.Types.Blue, "the moved item back at its old path");
      Assert_Once (Dest, Files.Types.Red, "the replaced item back at its path");
      Files_Suite.Support.Assert_Equal (Natural (Settings.Labels.Length), 2, "and no label is left elsewhere");
      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Replace_Move_References;
