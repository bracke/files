with Files.File_Types;
with Project_Tools.Text;
separate (Files_Suite.Operations)
   --  The compiled-in icon definitions are a copy of share/files/icons, which
   --  stays the one place icons are edited: every bundled .icon file, in every
   --  theme, must have a compiled-in copy equal to it, and every icon the
   --  renderer can ask for must have one. Guikit holds no icons of its own, so
   --  the registered source is what draws.
   procedure Test_Builtin_Icons_Match_Share (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      type Name_List is array (Positive range <>) of Unbounded_String;

      Icons_Root    : constant String := Files.Resources.Share_Path ("files/icons");
      Themes        : constant Name_List := [To_Unbounded_String (""), To_Unbounded_String ("files-high-contrast")];
      Toolbar_Icons : constant Name_List :=
        [To_Unbounded_String ("toolbar-home"), To_Unbounded_String ("toolbar-back"),
         To_Unbounded_String ("toolbar-forward"), To_Unbounded_String ("toolbar-parent"),
         To_Unbounded_String ("toolbar-create"), To_Unbounded_String ("toolbar-delete")];
      Compared      : Natural := 0;

      --  Compare every .icon file in Directory with its compiled-in copy.
      procedure Compare_Theme (Directory : String; Theme_Name : String) is
         Search : Ada.Directories.Search_Type;
         Found  : Ada.Directories.Directory_Entry_Type;
      begin
         Ada.Directories.Start_Search
           (Search, Directory, "*.icon", [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Found);
            declare
               Id : constant String := Ada.Directories.Base_Name (Ada.Directories.Simple_Name (Found));
            begin
               Files_Suite.Support.Assert_Equal
                 (Files.Icon_Assets.Builtin_Icon_Asset (Id, Theme_Name),
                  To_String (Project_Tools.Text.Read_Text_File (Ada.Directories.Full_Name (Found))),
                  "the compiled-in '" & Id & "' icon equals " & Ada.Directories.Full_Name (Found));
               Compared := Compared + 1;
            end;
         end loop;
         Ada.Directories.End_Search (Search);
      end Compare_Theme;

      --  The icon has a compiled-in definition that parses, in both themes.
      procedure Require_Builtin (Id : String) is
      begin
         for Theme_Name of Themes loop
            Assert
              (Guikit.Draw.Parse_Icon_Asset
                 (Files.Icon_Assets.Builtin_Icon_Asset (Id, To_String (Theme_Name))).Valid,
               "the '" & Id & "' icon has a compiled-in definition in theme '" & To_String (Theme_Name) & "'");
         end loop;
      end Require_Builtin;
   begin
      Assert (Icons_Root /= "", "the bundled icons folder is found");
      Compare_Theme (Icons_Root, "");
      Compare_Theme (Icons_Root & "/high-contrast", "files-high-contrast");
      Assert (Compared >= 2 * 15, "every bundled icon file is compared, got" & Natural'Image (Compared));

      for Icon in Files.File_Types.Icon_Kind loop
         Require_Builtin (Files.File_Types.Icon_Name (Icon));
      end loop;
      Require_Builtin (Files.File_Types.Thumbnail_Icon_Name);
      for Id of Toolbar_Icons loop
         Require_Builtin (To_String (Id));
      end loop;

      Assert
        (Files.Icon_Assets.Builtin_Icon_Asset ("not-an-icon", "") = ""
         and then Files.Icon_Assets.Builtin_Icon_Asset ("../folder", "") = ""
         and then Files.Icon_Assets.Builtin_Icon_Asset ("folder", "no-such-theme") = "",
         "there is no compiled-in definition for an icon or theme files does not ship");

      --  What draws: the registered source, the bundled file when it parses.
      Assert
        (Guikit.Draw.Parse_Icon_Asset (Guikit.Draw.Icon_Asset_Text ("folder", "files-basic")).Valid,
         "the files icon source is installed in Guikit.Draw");
      Files_Suite.Support.Assert_Equal
        (Files.Icon_Assets.Icon_Asset ("markdown", "files-high-contrast"),
         Files.Icon_Assets.Builtin_Icon_Asset ("markdown", "files-high-contrast"),
         "the source serves the bundled definition");
      Assert
        (Files.Icon_Assets.Icon_Asset ("not-an-icon", "") = "",
         "the source has no definition for an icon files does not ship");
   end Test_Builtin_Icons_Match_Share;
