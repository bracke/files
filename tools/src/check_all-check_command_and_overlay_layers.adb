separate (Check_All)
   procedure Check_Command_And_Overlay_Layers is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;

      --  The with clauses parsed (a list or a split clause cannot hide one),
      --  and no qualified name either, in the spec, the body and every
      --  subunit; the Status and Execution children are meant to use it.
      procedure Check (Path : String) is
      begin
         Require_Only_Allowed_With_Clauses (Path, "Files.Model", No_Units);
         Require_Not_Contains (Path, "Files.Model.", "Files.Commands must not read the model");
      end Check;
   begin
      Check (Root & "/src/files-commands.ads");
      Check (Root & "/src/files-commands.adb");
      Ada.Directories.Start_Search
        (Search, Root & "/src", "files-commands-*.adb", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         if Ada.Strings.Fixed.Index
              (To_String (Project_Tools.Text.Read_Text_File (Ada.Directories.Full_Name (Item))),
               "separate (Files.Commands)") > 0
         then
            Check (Ada.Directories.Full_Name (Item));
         end if;
      end loop;
      Ada.Directories.End_Search (Search);
      for Pattern of String_List'
        [To_Unbounded_String ("Build_Frame"),
         To_Unbounded_String ("Files.Localization")]
      loop
         Require_Not_Contains_In_Unit
           (Root & "/src/files-model.adb", To_String (Pattern),
            "the model holds overlay state; Files.Overlays draws and localizes it (" & To_String (Pattern) & ")");
         --  The specs too: a with clause there reaches every model body,
         --  which could then use the unit by a name this check never sees.
         Ada.Directories.Start_Search
           (Search, Root & "/src", "files-model*.ads", [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            Require_Not_Contains
              (Ada.Directories.Full_Name (Item), To_String (Pattern),
               "the model holds overlay state; Files.Overlays draws and localizes it (" & To_String (Pattern)
               & ", " & Ada.Directories.Simple_Name (Item) & ")");
         end loop;
         Ada.Directories.End_Search (Search);
      end loop;
   end Check_Command_And_Overlay_Layers;
