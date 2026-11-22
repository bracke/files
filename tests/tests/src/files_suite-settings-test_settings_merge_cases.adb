with Files.Settings.Path_References.Testing;
with Files.Settings.Storage.Testing;
with Files.Text_Basics;
with Files.Settings.Open_Actions;
with Files.Settings.Path_References;
with Files.Settings.Storage;
with Files.Settings.Testing;
separate (Files_Suite.Settings)
   --  The three-way merge a save makes (Storage.Write): Base is the file as
   --  this process last saw it, the other process writes its change over
   --  it, this one saves its own. Each case checks the merged settings and
   --  the file they were written to.
   procedure Test_Settings_Merge_Cases (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Files.Preference_Types;
      package Refs renames Files.Settings.Path_References;

      Path : constant String := Join (Root, "merge-cases.conf");

      type Change is access procedure (Settings : in out Files.Settings.Settings_Model);
      type Check is access function (Settings : Files.Settings.Settings_Model) return Boolean;

      function P (Name : String) return String is (Join (Root, Name));

      procedure Merge_Case (Name : String; Setup, Other, Own : Change; Expect : Check) is
         Base    : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Loaded  : Files.Settings.Settings_Parse_Result;
         Mine    : Files.Settings.Settings_Model;
         Theirs  : Files.Settings.Settings_Model;
         Written : Files.Settings.Settings_Write_Result;
      begin
         Setup (Base);
         Written := Files.Settings.Storage.Testing.Save_Text (Path, Files.Settings.To_Text (Base));
         Assert (Written.Success, Name & ": the base file is written");
         Loaded := Files.Settings.Storage.Load_File (Path);
         Assert (Loaded.Success, Name & ": and loaded by this process");
         Mine := Loaded.Settings;
         Theirs := Loaded.Settings;
         Other (Theirs);
         Write_File (Path, Files.Settings.To_Text (Theirs));
         Own (Mine);
         Written := Files.Settings.Storage.Testing.Write (Path, Mine);
         Assert (Written.Success, Name & ": the save succeeds");
         Assert (Expect (Mine), Name & ": the merged settings");
         Loaded := Files.Settings.Storage.Load_File (Path);
         Assert (Loaded.Success and then Expect (Loaded.Settings), Name & ": the file holds the merge");
      end Merge_Case;

      procedure Nothing (Settings : in out Files.Settings.Settings_Model) is null;

      --  The same scalar changed on both sides: this process's value wins;
      --  one only the other changed is taken.
      procedure Font_20_Hidden_On (Settings : in out Files.Settings.Settings_Model) is
      begin
         Settings.Font_Pixel_Size := 20;
         Settings.Show_Hidden_Files := True;
      end Font_20_Hidden_On;
      procedure Font_18 (Settings : in out Files.Settings.Settings_Model) is
      begin
         Settings.Font_Pixel_Size := 18;
      end Font_18;
      function Scalars_Merged (Settings : Files.Settings.Settings_Model) return Boolean is
        (Settings.Font_Pixel_Size = 18 and then Settings.Show_Hidden_Files);

      --  Removals on either side are kept: neither brings back what the
      --  other removed.
      procedure Three_Favorites (Settings : in out Files.Settings.Settings_Model) is
      begin
         Refs.Add_Favorite (Settings, P ("fav-a"));
         Refs.Add_Favorite (Settings, P ("fav-b"));
         Refs.Add_Favorite (Settings, P ("fav-c"));
      end Three_Favorites;
      procedure Drop_B (Settings : in out Files.Settings.Settings_Model) is
      begin
         Refs.Toggle_Favorite_Path (Settings, P ("fav-b"));
      end Drop_B;
      procedure Drop_C_Add_D (Settings : in out Files.Settings.Settings_Model) is
      begin
         Refs.Toggle_Favorite_Path (Settings, P ("fav-c"));
         Refs.Toggle_Favorite_Path (Settings, P ("fav-d"));
      end Drop_C_Add_D;
      function Favorites_Merged (Settings : Files.Settings.Settings_Model) return Boolean is
        (Refs.Is_Favorite (Settings, P ("fav-a"))
         and then not Refs.Is_Favorite (Settings, P ("fav-b"))
         and then not Refs.Is_Favorite (Settings, P ("fav-c"))
         and then Refs.Is_Favorite (Settings, P ("fav-d"))
         and then Natural (Refs.Favorite_Paths (Settings).Length) = 2);

      --  Labels merge path by path: a relabel, a clear and an addition on
      --  either side all survive.
      procedure Two_Labels (Settings : in out Files.Settings.Settings_Model) is
      begin
         Refs.Testing.Set_Label (Settings, P ("lab-a"), Red);
         Refs.Testing.Set_Label (Settings, P ("lab-b"), Orange);
      end Two_Labels;
      procedure Relabel_A_Add_C (Settings : in out Files.Settings.Settings_Model) is
      begin
         Refs.Testing.Set_Label (Settings, P ("lab-a"), Green);
         Refs.Testing.Set_Label (Settings, P ("lab-c"), Red);
      end Relabel_A_Add_C;
      procedure Clear_B_Add_D (Settings : in out Files.Settings.Settings_Model) is
      begin
         Refs.Testing.Set_Label (Settings, P ("lab-b"), No_Label);
         Refs.Testing.Set_Label (Settings, P ("lab-d"), Blue);
      end Clear_B_Add_D;
      function Labels_Merged (Settings : Files.Settings.Settings_Model) return Boolean is
        (Refs.Label_Of (Settings, P ("lab-a")) = Green
         and then Refs.Label_Of (Settings, P ("lab-b")) = No_Label
         and then Refs.Label_Of (Settings, P ("lab-c")) = Red
         and then Refs.Label_Of (Settings, P ("lab-d")) = Blue);

      --  Recent items: what this process opened since comes first, then the
      --  file's (the other's opening at its head), capped at the limit.
      procedure Full_Recent (Settings : in out Files.Settings.Settings_Model) is
      begin
         for N in 1 .. Files.Settings.Max_Recent_Items loop
            Refs.Add_Recent (Settings, P ("recent-" & Files.Text_Basics.Natural_Text (N)));
         end loop;
      end Full_Recent;
      procedure Open_X (Settings : in out Files.Settings.Settings_Model) is
      begin
         Refs.Note_Recent (Settings, P ("opened-x"));
      end Open_X;
      procedure Open_Y (Settings : in out Files.Settings.Settings_Model) is
      begin
         Refs.Note_Recent (Settings, P ("opened-y"));
      end Open_Y;
      function Recent_Merged (Settings : Files.Settings.Settings_Model) return Boolean is
         Recent : constant Files.Types.String_Vectors.Vector := Refs.Recent_Paths (Settings);
      begin
         return Natural (Recent.Length) = Files.Settings.Max_Recent_Items
           and then To_String (Recent (1)) = P ("opened-y")
           and then To_String (Recent (2)) = P ("opened-x")
           and then To_String (Recent (3)) = P ("recent-1")
           and then To_String (Recent.Last_Element)
                      = P ("recent-" & Files.Text_Basics.Natural_Text (Files.Settings.Max_Recent_Items - 2));
      end Recent_Merged;

      --  Extension and icon mappings merge key by key.
      procedure Two_Extensions (Settings : in out Files.Settings.Settings_Model) is
      begin
         Files.Settings.Testing.Add_Extension_Mapping (Settings, "mrga", "text/x-merge-a");
         Files.Settings.Testing.Add_Extension_Mapping (Settings, "mrgb", "text/x-merge-b");
      end Two_Extensions;
      procedure Remap_A_Add_C (Settings : in out Files.Settings.Settings_Model) is
      begin
         Files.Settings.Testing.Add_Extension_Mapping (Settings, "mrga", "text/x-merge-other");
         Files.Settings.Testing.Add_Extension_Mapping (Settings, "mrgc", "text/x-merge-c");
         Files.Settings.Testing.Add_Icon_Mapping (Settings, "text/x-merge-a", "icon-theirs");
      end Remap_A_Add_C;
      procedure Drop_B_Add_D (Settings : in out Files.Settings.Settings_Model) is
      begin
         Settings.Extension_Filetypes.Exclude ("mrgb");
         Files.Settings.Testing.Add_Extension_Mapping (Settings, "mrgd", "text/x-merge-d");
         Files.Settings.Testing.Add_Icon_Mapping (Settings, "text/x-merge-b", "icon-mine");
      end Drop_B_Add_D;
      function Mappings_Merged (Settings : Files.Settings.Settings_Model) return Boolean is
        (Settings.Extension_Filetypes.Contains ("mrga")
         and then Settings.Extension_Filetypes.Element ("mrga") = "text/x-merge-other"
         and then not Settings.Extension_Filetypes.Contains ("mrgb")
         and then Settings.Extension_Filetypes.Contains ("mrgc")
         and then Settings.Extension_Filetypes.Contains ("mrgd")
         and then Settings.Icon_Mappings.Contains ("text/x-merge-a")
         and then Settings.Icon_Mappings.Element ("text/x-merge-a") = "icon-theirs"
         and then Settings.Icon_Mappings.Contains ("text/x-merge-b")
         and then Settings.Icon_Mappings.Element ("text/x-merge-b") = "icon-mine");

      --  Open actions merge token by token; one both set is this process's.
      function Action (Executable : String) return Files.Settings.Open_Action is
         Args : Files.Types.String_Vectors.Vector;
      begin
         Args.Append (To_Unbounded_String ("{path}"));
         return Files.Settings.Open_Actions.Make_Action (Executable, Args);
      end Action;
      procedure Their_Actions (Settings : in out Files.Settings.Settings_Model) is
      begin
         Files.Settings.Testing.Add_Open_Action (Settings, "text/x-theirs", Action ("theirs"));
         Files.Settings.Testing.Add_Open_Action (Settings, "text/x-both", Action ("theirs-both"));
      end Their_Actions;
      procedure My_Actions (Settings : in out Files.Settings.Settings_Model) is
      begin
         Files.Settings.Testing.Add_Open_Action (Settings, "text/x-mine", Action ("mine"));
         Files.Settings.Testing.Add_Open_Action (Settings, "text/x-both", Action ("mine-both"));
      end My_Actions;
      function Executable_Of (Settings : Files.Settings.Settings_Model; Token : String) return String is
        (if Settings.Open_Actions.Contains (Token)
         then To_String (Settings.Open_Actions.Element (Token).Executable)
         else "");
      function Actions_Merged (Settings : Files.Settings.Settings_Model) return Boolean is
        (Executable_Of (Settings, "text/x-theirs") = "theirs"
         and then Executable_Of (Settings, "text/x-mine") = "mine"
         and then Executable_Of (Settings, "text/x-both") = "mine-both");
      --  Shortcut overrides merge command by command: a rebind the other
      --  made to an override both had is taken, one this process added kept.
      function Override
        (Command : Files.Commands.Command_Id;
         Combo   : String) return Files.Settings.Shortcut_Override is
        ((Command => To_Unbounded_String (Files.Commands.Identifier (Command)),
          Combo   => To_Unbounded_String (Combo)));
      procedure One_Override (Settings : in out Files.Settings.Settings_Model) is
      begin
         Settings.Shortcut_Overrides.Append (Override (Files.Commands.Select_Small_Icons_Command, "control+shift+1"));
      end One_Override;
      procedure Rebind (Settings : in out Files.Settings.Settings_Model) is
      begin
         Settings.Shortcut_Overrides.Replace_Element
           (1, Override (Files.Commands.Select_Small_Icons_Command, "control+shift+2"));
      end Rebind;
      procedure Add_Large (Settings : in out Files.Settings.Settings_Model) is
      begin
         Settings.Shortcut_Overrides.Append (Override (Files.Commands.Select_Large_Icons_Command, "control+shift+3"));
      end Add_Large;
      function Combo_Of (Settings : Files.Settings.Settings_Model; Command : Files.Commands.Command_Id) return String is
      begin
         for Item of Settings.Shortcut_Overrides loop
            if To_String (Item.Command) = Files.Commands.Identifier (Command) then
               return To_String (Item.Combo);
            end if;
         end loop;
         return "";
      end Combo_Of;
      function Overrides_Merged (Settings : Files.Settings.Settings_Model) return Boolean is
        (Combo_Of (Settings, Files.Commands.Select_Small_Icons_Command) = "control+shift+2"
         and then Combo_Of (Settings, Files.Commands.Select_Large_Icons_Command) = "control+shift+3");
   begin
      Reset_Root;
      Merge_Case ("scalars", Nothing'Access, Font_20_Hidden_On'Access, Font_18'Access, Scalars_Merged'Access);
      Merge_Case ("favorites", Three_Favorites'Access, Drop_B'Access, Drop_C_Add_D'Access, Favorites_Merged'Access);
      Merge_Case ("labels", Two_Labels'Access, Relabel_A_Add_C'Access, Clear_B_Add_D'Access, Labels_Merged'Access);
      Merge_Case ("recent", Full_Recent'Access, Open_X'Access, Open_Y'Access, Recent_Merged'Access);
      Merge_Case ("mappings", Two_Extensions'Access, Remap_A_Add_C'Access, Drop_B_Add_D'Access, Mappings_Merged'Access);
      Merge_Case ("open actions", Nothing'Access, Their_Actions'Access, My_Actions'Access, Actions_Merged'Access);
      Merge_Case ("shortcuts", One_Override'Access, Rebind'Access, Add_Large'Access, Overrides_Merged'Access);
   end Test_Settings_Merge_Cases;
