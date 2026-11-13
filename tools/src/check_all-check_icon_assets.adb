separate (Check_All)
   procedure Check_Icon_Assets is
      procedure Fail_Icon
        (Path    : String;
         Message : String) is
      begin
         Put_Line (Standard_Error, Path & ": " & Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail_Icon;

      function Try_Parse_Natural
        (Text  : String;
         Value : out Natural)
         return Boolean
      is
         Clean : constant String := Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      begin
         Value := 0;
         if Clean = "" then
            return False;
         end if;

         for Position in Clean'Range loop
            if Clean (Position) not in '0' .. '9'
              or else Value > (Natural'Last - Character'Pos (Clean (Position)) + Character'Pos ('0')) / 10
            then
               return False;
            end if;
            Value := Value * 10 + Character'Pos (Clean (Position)) - Character'Pos ('0');
         end loop;

         return True;
      end Try_Parse_Natural;

      function Field
        (Text  : String;
         Index : Positive)
         return String
      is
         Start : Positive := Text'First;
         Count : Positive := 1;
      begin
         if Text = "" then
            return "";
         end if;

         for Position in Text'Range loop
            if Text (Position) = ',' then
               if Count = Index then
                  return Text (Start .. Position - 1);
               end if;
               Count := Count + 1;
               Start := Position + 1;
            end if;
         end loop;

         if Count = Index then
            return Text (Start .. Text'Last);
         else
            return "";
         end if;
      end Field;

      function Value_After_Prefix
        (Text   : String;
         Prefix : String)
         return String is
      begin
         if Text'Length <= Prefix'Length then
            return "";
         else
            return Text (Text'First + Prefix'Length .. Text'Last);
         end if;
      end Value_After_Prefix;

      function Valid_Icon_Role (Role : String) return Boolean is
         Clean : constant String := Ada.Strings.Fixed.Trim (Role, Ada.Strings.Both);
      begin
         return Clean = "base"
           or else Clean = "accent"
           or else Clean = "border"
           or else Clean = "muted";
      end Valid_Icon_Role;

      procedure Require_Valid_Icon_Asset
        (Path          : String;
         Expected_Name : String)
      is separate;
   begin
      Project_Tools.Files.Require_Files
        ([To_Unbounded_String (Root & "/share/files/icons/folder.icon"),
          To_Unbounded_String (Root & "/share/files/icons/text.icon"),
          To_Unbounded_String (Root & "/share/files/icons/image.icon"),
          To_Unbounded_String (Root & "/share/files/icons/executable.icon"),
          To_Unbounded_String (Root & "/share/files/icons/link.icon"),
          To_Unbounded_String (Root & "/share/files/icons/unknown.icon"),
          To_Unbounded_String (Root & "/share/files/icons/ada.icon"),
          To_Unbounded_String (Root & "/share/files/icons/markdown.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/folder.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/text.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/image.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/executable.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/link.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/unknown.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/ada.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/markdown.icon")],
         "files icon assets must be present");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/folder.icon", "folder");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/text.icon", "text");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/image.icon", "image");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/executable.icon", "executable");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/link.icon", "link");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/unknown.icon", "unknown");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/ada.icon", "ada");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/markdown.icon", "markdown");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/folder.icon", "folder");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/text.icon", "text");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/image.icon", "image");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/executable.icon", "executable");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/link.icon", "link");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/unknown.icon", "unknown");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/ada.icon", "ada");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/markdown.icon", "markdown");
   end Check_Icon_Assets;
