separate (Check_All)
   procedure Check_Command_Localization_Keys is
      use Tokens;

      Commands : constant String := Root & "/src/files-commands.adb";
      Catalog  : constant String := Root & "/share/files.catalog";

      procedure Require_Key (Key : String) is
      begin
         if Starts_With (Key, "command.") then
            Project_Tools.Files.Require_Contains
              (Catalog,
               "en." & Key & " = ",
               "command localization key must exist in share/files.catalog: " & Key);
         end if;
      end Require_Key;
   begin
      for Item of Tokens_Of (To_String (Project_Tools.Text.Read_Text_File (Commands)), Preserve_Case => True) loop
         if Item.Kind = Literal and then not Item.Is_Character then
            Require_Key (To_String (Item.Text));
         end if;
      end loop;
   end Check_Command_Localization_Keys;
