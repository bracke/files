with Ada.Strings.Fixed;
with Files.Settings.Path_References;
separate (Files_Suite.Settings)
   --  A hand-edited settings file that lists a favorite or a recent item
   --  twice loads it once: the root selector and the recent list never show
   --  one folder twice, and taking the favorite off takes it off.
   procedure Test_Settings_File_Repeats_Load_Once (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Favorite : constant String := "/home/user/docs";
      Base     : Files.Settings.Settings_Model := Files.Settings.Default_Settings;

      --  Text with the first line containing Marker written twice.
      function Repeated (Text, Marker : String) return String is
         At_Marker : constant Natural := Ada.Strings.Fixed.Index (Text, Marker);
         Line_End  : constant Natural := Ada.Strings.Fixed.Index (Text, [ASCII.LF], From => At_Marker);
         Line_Start : Natural := At_Marker;
      begin
         while Line_Start > Text'First and then Text (Line_Start - 1) /= ASCII.LF loop
            Line_Start := Line_Start - 1;
         end loop;
         return Text (Text'First .. Line_End) & Text (Line_Start .. Line_End) & Text (Line_End + 1 .. Text'Last);
      end Repeated;
   begin
      Files.Settings.Path_References.Toggle_Favorite_Path (Base, Favorite);
      Files.Settings.Path_References.Note_Recent (Base, "/home/user/old.txt");
      Files.Settings.Path_References.Note_Recent (Base, "/home/user/new.txt");
      declare
         Text   : constant String :=
           Repeated (Repeated (Files.Settings.To_Text (Base), "bookmark = "), "recent = ");
         Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Text);
         Loaded : Files.Settings.Settings_Model := Parsed.Settings;
      begin
         Assert (Parsed.Success, "a file with repeated entries still loads");
         Assert
           (Ada.Strings.Fixed.Count (Text, "bookmark = ") = 2 and then Ada.Strings.Fixed.Count (Text, "recent = ") = 3,
            "the file lists the favorite twice and one recent item twice");
         Files_Suite.Support.Assert_Equal
           (Natural (Files.Settings.Path_References.Favorite_Paths (Loaded).Length), 1, "the favorite loads once");
         Files_Suite.Support.Assert_Equal
           (Natural (Files.Settings.Path_References.Recent_Paths (Loaded).Length), 2, "each recent item loads once");
         Files.Settings.Path_References.Toggle_Favorite_Path (Loaded, Favorite);
         Assert
           (not Files.Settings.Path_References.Is_Favorite (Loaded, Favorite),
            "taking the favorite off takes it off");
      end;
   end Test_Settings_File_Repeats_Load_Once;
