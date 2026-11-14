separate (Files_Suite.Names)
   --  A case-only rename whose second hop and way back both fail leaves the
   --  entry at its scratch name; the error then says where, in every locale,
   --  through the window's error line. (Both hops failing cannot be provoked
   --  from a test, so the message the user reads is checked here.)
   procedure Test_Rename_Stranded_Message (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Key      : constant String := Files.File_System.Rename_Stranded_Key;
      Left_At  : constant String := Join (Root, "Notes (renaming).txt");
      Model    : Files.Model.Window_Model;
      Locales  : constant Files.Types.String_Vectors.Vector :=
        [To_Unbounded_String ("da-DK"), To_Unbounded_String ("de-DE"), To_Unbounded_String ("es-ES"),
         To_Unbounded_String ("fr-FR"), To_Unbounded_String ("it-IT"), To_Unbounded_String ("nl-NL"),
         To_Unbounded_String ("pt-PT"), To_Unbounded_String ("sv-SE"), To_Unbounded_String ("nb-NO"),
         To_Unbounded_String ("fi-FI")];

      function Names_Path (Text : String) return Boolean is (Ada.Strings.Fixed.Index (Text, Left_At) > 0);
   begin
      Reset_Root;
      Assert (Names_Path (Files.Localization.Text (Key, "path", Left_At, "en")), "the message names the path");
      for Locale of Locales loop
         declare
            Text : constant String := Files.Localization.Text (Key, "path", Left_At, To_String (Locale));
         begin
            Assert (Names_Path (Text), To_String (Locale) & " names the path");
            Assert
              (Text /= Files.Localization.Text (Key, "path", Left_At, "en"), To_String (Locale) & " translates it");
         end;
      end loop;

      Files.Model.Initialize (Model, Root, Files.Items.Item_Vectors.Empty_Vector, Root);
      Files.Model.Set_Error (Model, Key, Left_At);
      Files_Suite.Support.Assert_Equal (Files.Model.Last_Error_Key (Model), Key, "the window holds the error");
      Files_Suite.Support.Assert_Equal (Files.Model.Last_Error_Path (Model), Left_At, "and the path it names");
      declare
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
      begin
         Files_Suite.Support.Assert_Equal
           (To_String (Snapshot.Last_Error_Text),
            Files.Localization.Text (Key, "path", Left_At),
            "the error line shows the message with the path filled in");
      end;

      Files.Model.Set_Error (Model, "error.rename.failed");
      Files_Suite.Support.Assert_Equal (Files.Model.Last_Error_Path (Model), "", "a later error names no path");
      declare
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
      begin
         Files_Suite.Support.Assert_Equal
           (To_String (Snapshot.Last_Error_Text),
            Files.Localization.Text ("error.rename.failed"),
            "and its line is its own message");
      end;
   end Test_Rename_Stranded_Message;
