separate (Files_Suite.Settings)
   procedure Test_Recent_Items (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      File_Path   : constant String := "/home/user/report.txt";
      Folder_Path : constant String := "/home/user/projects";
      Base        : Files.Settings.Settings_Model := Files.Settings.Default_Settings;

      function Nth (Settings : Files.Settings.Settings_Model; Index : Positive) return String is
         Paths : constant Files.Types.String_Vectors.Vector :=
           Files.Settings.Recent_Paths (Settings);
      begin
         if Index <= Natural (Paths.Length) then
            return To_String (Paths.Element (Index));
         end if;
         return "";
      end Nth;

      function Count (Settings : Files.Settings.Settings_Model) return Natural is
      begin
         return Natural (Files.Settings.Recent_Paths (Settings).Length);
      end Count;
   begin
      --  A fresh model has no recents; the empty path is ignored.
      Files_Suite.Support.Assert_Equal (Count (Base), 0, "a fresh model has no recent items");
      Files.Settings.Note_Recent (Base, "");
      Files_Suite.Support.Assert_Equal (Count (Base), 0, "the empty path is not recorded");
      Files.Settings.Note_Recent
        (Base, File_Path & Character'Val (0) & "ignored");
      Files_Suite.Support.Assert_Equal (Count (Base), 0, "a NUL-containing path is not recorded as a recent item");
      Files.Settings.Note_Recent (Base, File_Path & ASCII.LF & "b");
      Files.Settings.Note_Recent (Base, File_Path & ASCII.CR);
      Files_Suite.Support.Assert_Equal
        (Count (Base),
         0,
         "a path with a line break is not recorded, since it cannot round-trip the line-based file");

      --  Note records most-recent-first (a file and a folder both round in).
      Files.Settings.Note_Recent (Base, File_Path);
      Files.Settings.Note_Recent (Base, Folder_Path);
      Files_Suite.Support.Assert_Equal (Count (Base), 2, "two distinct items are recorded");
      Files_Suite.Support.Assert_Equal (Nth (Base, 1), Folder_Path, "the most recent item is at the front");
      Files_Suite.Support.Assert_Equal (Nth (Base, 2), File_Path, "the earlier item follows");

      --  Re-noting an existing path moves it to the front and dedups.
      Files.Settings.Note_Recent (Base, File_Path);
      Files_Suite.Support.Assert_Equal (Count (Base), 2, "re-noting an existing path does not grow the list");
      Files_Suite.Support.Assert_Equal (Nth (Base, 1), File_Path, "a re-noted path moves to the front");
      Files_Suite.Support.Assert_Equal (Nth (Base, 2), Folder_Path, "the previously-front path drops back");

      --  Clearing empties the list.
      Files.Settings.Clear_Recent (Base);
      Files_Suite.Support.Assert_Equal (Count (Base), 0, "Clear_Recent empties the recent list");

      --  The list is capped at Max_Recent_Items, dropping the oldest entries.
      declare
         Capped : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         for I in 1 .. Files.Settings.Max_Recent_Items + 10 loop
            Files.Settings.Note_Recent
              (Capped, "/tmp/item" & Ada.Strings.Fixed.Trim (Integer'Image (I), Ada.Strings.Both));
         end loop;
         Files_Suite.Support.Assert_Equal
           (Count (Capped),
            Files.Settings.Max_Recent_Items,
            "the recent list is capped at Max_Recent_Items");
         Assert (Nth (Capped, 1) = "/tmp/item" &
                   Ada.Strings.Fixed.Trim
                     (Integer'Image (Files.Settings.Max_Recent_Items + 10), Ada.Strings.Both),
                 "the newest item is retained at the front");
         Files_Suite.Support.Assert_Equal
           (Nth (Capped, Files.Settings.Max_Recent_Items),
            "/tmp/item11",
            "the oldest surviving item sits at the cap boundary");
      end;

      --  Full round-trip through the settings text format preserves order, cap,
      --  and both file and folder paths.
      declare
         Source : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Files.Settings.Note_Recent (Source, File_Path);
         Files.Settings.Note_Recent (Source, Folder_Path);
         declare
            Reloaded : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse (Files.Settings.To_Text (Source));
         begin
            Assert (Reloaded.Success, "recent settings text parses");
            Files_Suite.Support.Assert_Equal (Count (Reloaded.Settings), 2, "both recent paths round-trip");
            Files_Suite.Support.Assert_Equal
              (Nth (Reloaded.Settings, 1),
               Folder_Path,
               "recent order is preserved most-recent-first");
            Files_Suite.Support.Assert_Equal
              (Nth (Reloaded.Settings, 2),
               File_Path,
               "the earlier recent path round-trips in order");
         end;
      end;

      --  A hand-edited file above the cap loads only the first Max_Recent_Items.
      declare
         Body_Text : Unbounded_String := To_Unbounded_String ("[recent]" & ASCII.LF);
      begin
         for I in 1 .. Files.Settings.Max_Recent_Items + 5 loop
            Append
              (Body_Text,
               "recent = ""/tmp/over" &
               Ada.Strings.Fixed.Trim (Integer'Image (I), Ada.Strings.Both) & """" & ASCII.LF);
         end loop;
         declare
            Parsed : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse (To_String (Body_Text));
         begin
            Assert (Parsed.Success, "an over-cap recent section still loads");
            Files_Suite.Support.Assert_Equal
              (Count (Parsed.Settings),
               Files.Settings.Max_Recent_Items,
               "loading enforces the recent cap");
         end;
      end;
   end Test_Recent_Items;
