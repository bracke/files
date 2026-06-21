with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Textrender;

with Files.Command_Palette;
with Files.File_Types;
with Files.Localization;
with Files.UI;

package body Files.Rendering is
   use Ada.Strings.Unbounded;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Files.Types.View_Mode;

   Info_Rows_Per_Item : constant Natural := 9;

   function Contains_Rectangle_Point
     (X        : Natural;
      Y        : Natural;
      Box_W    : Natural;
      Box_H    : Natural;
      Point_X  : Natural;
      Point_Y  : Natural)
      return Boolean
   is
   begin
      return Box_W > 0
        and then Box_H > 0
        and then Point_X >= X
        and then Point_Y >= Y
        and then Point_X - X < Box_W
        and then Point_Y - Y < Box_H;
   end Contains_Rectangle_Point;

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural is
   begin
      if Left > Natural'Last - Right then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

   function Saturating_Multiply
     (Value  : Natural;
      Factor : Natural)
      return Natural is
   begin
      if Factor = 0 then
         return 0;
      elsif Value > Natural'Last / Factor then
         return Natural'Last;
      else
         return Value * Factor;
      end if;
   end Saturating_Multiply;

   function Scaled_Down
     (Value       : Natural;
      Numerator   : Positive;
      Denominator : Positive)
      return Natural is
   begin
      return
        Saturating_Add
          (Saturating_Multiply (Value / Denominator, Numerator),
           Saturating_Multiply (Value mod Denominator, Numerator) / Denominator);
   end Scaled_Down;

   function Paired_Row_Count
     (Keys   : Files.Types.String_Vectors.Vector;
      Values : Files.Types.String_Vectors.Vector)
      return Natural is
   begin
      return Natural'Min (Natural (Keys.Length), Natural (Values.Length));
   end Paired_Row_Count;

   function Bounded_Product_Divide
     (Value       : Natural;
      Factor      : Natural;
      Denominator : Positive)
      return Natural is
   begin
      if Factor = 0 or else Value = 0 then
         return 0;
      elsif Value > Natural'Last / Factor then
         return Scaled_Down (Value, Factor, Denominator);
      else
         return (Value * Factor) / Denominator;
      end if;
   end Bounded_Product_Divide;

   function Visible_Row_Count
     (Available_Height : Natural;
      Row_Height       : Natural)
      return Natural is
   begin
      if Available_Height = 0 or else Row_Height = 0 then
         return 0;
      end if;

      return Available_Height / Row_Height
        + (if Available_Height mod Row_Height = 0 then 0 else 1);
   end Visible_Row_Count;

   function Saturating_Integer_Add
     (Left  : Integer;
      Right : Natural)
      return Integer is
   begin
      if Left > Integer'Last - Integer (Right) then
         return Integer'Last;
      else
         return Left + Integer (Right);
      end if;
   end Saturating_Integer_Add;

   function Default_Theme return Render_Theme is
   begin
      return
        (Name             => To_Unbounded_String ("default"),
         High_Contrast    => False,
         Selection_Strong => False,
         Focus_Ring       => Border_Color,
         Warning_Color    => Error_Text_Color);
   end Default_Theme;

   function High_Contrast_Theme return Render_Theme is
   begin
      return
        (Name             => To_Unbounded_String ("high_contrast"),
         High_Contrast    => True,
         Selection_Strong => True,
         Focus_Ring       => Selection_Color,
         Warning_Color    => Error_Text_Color);
   end High_Contrast_Theme;

   function Default_Accessibility_Profile return Accessibility_Profile is
   begin
      return
        (Keyboard_Navigation => True,
         Focus_Rings         => True,
         High_Contrast       => False,
         Tooltips            => True,
         Text_Truncation     => True,
         Screen_Reader_Role_Metadata => True);
   end Default_Accessibility_Profile;

   function High_Contrast_Accessibility_Profile return Accessibility_Profile is
   begin
      return
        (Keyboard_Navigation => True,
         Focus_Rings         => True,
         High_Contrast       => True,
         Tooltips            => True,
         Text_Truncation     => True,
         Screen_Reader_Role_Metadata => True);
   end High_Contrast_Accessibility_Profile;

   function Accessibility_Integration_Profile_Of_Current_UI
      return Accessibility_Integration_Profile is
   begin
      return
        (Render_Node_Tree          => True,
         Native_API_Binding_Status => Files.File_System.Native_API_Binding_Missing,
         Role_Metadata             => True,
         Table_Metadata            => True,
         Pane_Section_Metadata     => True,
         Keyboard_Focus_Metadata   => True,
         Binding_Unit              =>
           To_Unbounded_String ("Files.Rendering.Frame_Commands.Accessibility"));
   end Accessibility_Integration_Profile_Of_Current_UI;

   function Settings_Editor_Profile_Of_Current_UI return Settings_Editor_Profile is
   begin
      return
        (Scalar_Controls       => 7,
         Mapping_Controls      => 4,
         Open_Action_Controls  => 2,
         Supports_Save         => True,
         Supports_Reset        => True,
         Supports_Import       => True,
         Supports_Export       => True,
         Per_Field_Diagnostics => True,
         Supports_Option_Cycling => True,
         Supports_Add_Remove_Mapping => True,
         Supports_Draft_Validation => True,
         Supports_Native_Dialog_Policy => True,
         Saves_Central_Settings => True);
   end Settings_Editor_Profile_Of_Current_UI;

   function Icon_Theme_Profile_Of_Current_UI return Icon_Theme_Profile is
   begin
      return
        (Theme_Name          => To_Unbounded_String ("files-basic"),
         Placeholder_Icons   => False,
         Scalable_Icons      => True,
         Filetype_Icons      => Natural (Bundled_Icon_Asset_Names.Length),
         Asset_Directory     => To_Unbounded_String ("share/files/icons"),
         Asset_Format        => To_Unbounded_String ("files-icon-v1"),
         User_Selectable     => True,
         High_Contrast_Ready => True);
   end Icon_Theme_Profile_Of_Current_UI;

   function Icon_Theme_Profile_For
     (Settings : Files.Settings.Settings_Model)
      return Icon_Theme_Profile
   is
      Theme : constant String := To_String (Settings.Icon_Theme_Name);
   begin
      if Theme = "files-high-contrast" then
         return
           (Theme_Name          => To_Unbounded_String ("files-high-contrast"),
            Placeholder_Icons   => False,
            Scalable_Icons      => True,
            Filetype_Icons      => Natural (Bundled_Icon_Asset_Names.Length),
            Asset_Directory     => To_Unbounded_String ("share/files/icons/high-contrast"),
            Asset_Format        => To_Unbounded_String ("files-icon-v1"),
            User_Selectable     => True,
            High_Contrast_Ready => True);
      end if;

      return Icon_Theme_Profile_Of_Current_UI;
   end Icon_Theme_Profile_For;

   function Bundled_Icon_Asset_Names return Files.Types.String_Vectors.Vector is
      Names : Files.Types.String_Vectors.Vector;
   begin
      Names.Append (To_Unbounded_String ("folder"));
      Names.Append (To_Unbounded_String ("text"));
      Names.Append (To_Unbounded_String ("image"));
      Names.Append (To_Unbounded_String ("executable"));
      Names.Append (To_Unbounded_String ("link"));
      Names.Append (To_Unbounded_String ("unknown"));
      Names.Append (To_Unbounded_String ("ada"));
      Names.Append (To_Unbounded_String ("markdown"));
      return Names;
   end Bundled_Icon_Asset_Names;

   function Icon_Asset_Text
     (Icon_Id    : String;
      Theme_Name : String)
      return String
   is
      LF          : constant String := [1 => ASCII.LF];
      Corner_Role : constant String := (if Theme_Name = "files-high-contrast" then "border" else "muted");

      function Header (Asset_Name : String) return String is
      begin
         return "files-icon-v1" & LF & "name=" & Asset_Name & LF & "grid=16" & LF;
      end Header;

      function Document
        (Asset_Name : String;
         Body_Text  : String)
         return String is
      begin
         return
           Header (Asset_Name)
           & "rect=1,0,14,16,base" & LF
           & "rect=11,0,4,4," & Corner_Role & LF
           & Body_Text;
      end Document;
   begin
      if Icon_Id = "folder" then
         return
           Header ("folder")
           & "rect=0,3,7,3,base" & LF
           & "rect=0,6,16,10,base" & LF
           & "rect=1,7,14,1,border" & LF
           & (if Theme_Name = "files-high-contrast" then "rect=1,14,14,1,border" & LF else "");
      elsif Icon_Id = "text" then
         return
           Document
             ("text",
              "rect=4,6,8,1,border" & LF
              & "rect=4,9,8,1,border" & LF
              & "rect=4,12,6,1,border" & LF);
      elsif Icon_Id = "image" then
         return
           Document
             ("image",
              "rect=3,5,10,6,accent" & LF
              & "rect=4,8,4,2,border" & LF
              & "rect=8,7,4,3,border" & LF);
      elsif Icon_Id = "executable" then
         return
           Document
             ("executable",
              "rect=1,0,3,16,accent" & LF
              & "rect=7,5,3,6,accent" & LF
              & "rect=10,8,3,3,accent" & LF);
      elsif Icon_Id = "link" then
         return
           Document
             ("link",
              "rect=3,8,8,2,accent" & LF
              & "rect=8,5,5,2,accent" & LF
              & "rect=8,11,5,2,accent" & LF);
      elsif Icon_Id = "unknown" then
         return
           Document
             ("unknown",
              "rect=5,4,6,2,border" & LF
              & "rect=8,6,2,5,border" & LF
              & "rect=8,13,2,1,border" & LF);
      elsif Icon_Id = "ada" then
         return
           Document
             ("ada",
              "rect=4,5,3,8,accent" & LF
              & "rect=9,5,3,8,accent" & LF
              & "rect=5,8,6,2,border" & LF);
      elsif Icon_Id = "markdown" then
         return
           Document
             ("markdown",
              "rect=4,5,2,8,border" & LF
              & "rect=7,8,2,5,border" & LF
              & "rect=10,5,2,8,border" & LF);
      else
         return "";
      end if;
   end Icon_Asset_Text;

   function Parse_Icon_Asset
     (Content : String)
      return Icon_Asset
   is
      Result      : Icon_Asset;
      Saw_Header  : Boolean := False;
      Saw_Name    : Boolean := False;
      Saw_Grid    : Boolean := False;
      Parse_Failed : Boolean := False;

      function Starts_With
        (Value  : String;
         Prefix : String)
         return Boolean is
      begin
         return Value'Length >= Prefix'Length
           and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
      end Starts_With;

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

      function Try_Parse_Role
        (Text : String;
         Role : out Icon_Asset_Color_Role)
         return Boolean
      is
         Clean : constant String := Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      begin
         if Clean = "base" then
            Role := Icon_Asset_Base;
            return True;
         elsif Clean = "accent" then
            Role := Icon_Asset_Accent;
            return True;
         elsif Clean = "border" then
            Role := Icon_Asset_Border;
            return True;
         elsif Clean = "muted" then
            Role := Icon_Asset_Muted;
            return True;
         else
            Role := Icon_Asset_Base;
            return False;
         end if;
      end Try_Parse_Role;

      function Field
        (Text  : String;
         Index : Positive)
         return String
      is
         Start : Positive := Text'First;
         Count : Positive := 1;
      begin
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

      function Fits_Grid (Rect : Icon_Asset_Rect) return Boolean is
      begin
         return Rect.Grid_X < Result.Grid
           and then Rect.Grid_Y < Result.Grid
           and then Rect.Grid_W <= Result.Grid - Rect.Grid_X
           and then Rect.Grid_H <= Result.Grid - Rect.Grid_Y;
      end Fits_Grid;

      procedure Parse_Line
        (Raw_Line : String)
      is
         Line : constant String := Ada.Strings.Fixed.Trim (Raw_Line, Ada.Strings.Both);
      begin
         if Line = "" then
            return;
         elsif not Saw_Header then
            Saw_Header := Line = "files-icon-v1";
         elsif Starts_With (Line, "name=") then
            Result.Name := To_Unbounded_String (Line (Line'First + 5 .. Line'Last));
            Saw_Name := Length (Result.Name) > 0;
         elsif Starts_With (Line, "grid=") then
            declare
               Grid_Value : Natural;
            begin
               if not Try_Parse_Natural (Line (Line'First + 5 .. Line'Last), Grid_Value)
                 or else Grid_Value = 0
               then
                  Parse_Failed := True;
                  return;
               end if;

               Result.Grid := Grid_Value;
               Saw_Grid := True;
            end;
         elsif Starts_With (Line, "rect=") then
            if not Saw_Grid then
               Parse_Failed := True;
               return;
            end if;

            declare
               Data  : constant String := Line (Line'First + 5 .. Line'Last);
               Rect  : Icon_Asset_Rect;
            begin
               if not Try_Parse_Natural (Field (Data, 1), Rect.Grid_X)
                 or else not Try_Parse_Natural (Field (Data, 2), Rect.Grid_Y)
                 or else not Try_Parse_Natural (Field (Data, 3), Rect.Grid_W)
                 or else not Try_Parse_Natural (Field (Data, 4), Rect.Grid_H)
                 or else not Try_Parse_Role (Field (Data, 5), Rect.Role)
               then
                  Parse_Failed := True;
                  return;
               end if;

               if Rect.Grid_W = 0 or else Rect.Grid_H = 0 or else not Fits_Grid (Rect) then
                  Parse_Failed := True;
                  return;
               end if;
               Result.Rectangles.Append (Rect);
            end;
         else
            Parse_Failed := True;
            return;
         end if;
      end Parse_Line;

      Line_Start : Positive := Content'First;
   begin
      if Content = "" then
         return Result;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            if Index > Line_Start then
               Parse_Line (Content (Line_Start .. Index - 1));
            else
               Parse_Line ("");
            end if;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Parse_Line (Content (Line_Start .. Content'Last));
      end if;

      Result.Valid :=
        not Parse_Failed
        and then Saw_Header
        and then Saw_Name
        and then Saw_Grid
        and then not Result.Rectangles.Is_Empty;
      return Result;
   exception
      when others =>
         Result.Valid := False;
         Result.Rectangles.Clear;
         return Result;
   end Parse_Icon_Asset;

   type Item_Cell_Metrics is record
      Width     : Natural := 0;
      Height    : Natural := 0;
      Icon_Size : Natural := 0;
      Large     : Boolean := False;
   end record;

   function Metrics_For
     (Mode        : Files.Types.View_Mode;
      Main_Width  : Natural;
      Line_Height : Positive)
      return Item_Cell_Metrics
   is
   begin
      case Mode is
         when Files.Types.Small_Icons =>
            return
              (Width     => 180,
               Height    => Line_Height,
               Icon_Size => Line_Height,
               Large     => False);
         when Files.Types.Large_Icons =>
            return
              (Width     => Saturating_Multiply (Line_Height, 7),
               Height    => Saturating_Multiply (Line_Height, 5),
               Icon_Size => Saturating_Multiply (Line_Height, 3),
               Large     => True);
         when Files.Types.Details =>
            return
              (Width     => Main_Width,
               Height    => Line_Height,
               Icon_Size => Line_Height,
               Large     => False);
      end case;
   end Metrics_For;

   function Build_Snapshot
     (Model : Files.Model.Window_Model)
      return View_Snapshot
   is
   begin
      return Build_Snapshot (Model, Files.Settings.Default_Settings);
   end Build_Snapshot;

   function Build_Snapshot
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return View_Snapshot
   is
      Snapshot : View_Snapshot;

      function Natural_Text (Value : Natural) return String is
         Image : constant String := Natural'Image (Value);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Natural_Text;

      function View_Mode_Text (Mode : Files.Types.View_Mode) return String is
      begin
         case Mode is
            when Files.Types.Small_Icons =>
               return Files.Localization.Text ("command.view.small");
            when Files.Types.Large_Icons =>
               return Files.Localization.Text ("command.view.large");
            when Files.Types.Details =>
               return Files.Localization.Text ("command.view.details");
         end case;
      end View_Mode_Text;

      function View_Mode_Token (Mode : Files.Types.View_Mode) return String is
      begin
         case Mode is
            when Files.Types.Small_Icons =>
               return "small_icons";
            when Files.Types.Large_Icons =>
               return "large_icons";
            when Files.Types.Details =>
               return "details";
         end case;
      end View_Mode_Token;

      function Boolean_Text (Value : Boolean) return String is
      begin
         return Files.Localization.Text ((if Value then "settings.value.true" else "settings.value.false"));
      end Boolean_Text;

      function Boolean_Token (Value : Boolean) return String is
      begin
         return (if Value then "true" else "false");
      end Boolean_Token;

      function Sort_Field_Text (Field : Files.Settings.Sort_Field) return String is
      begin
         case Field is
            when Files.Settings.Sort_By_Name =>
               return Files.Localization.Text ("settings.sort.name");
            when Files.Settings.Sort_By_Filetype =>
               return Files.Localization.Text ("settings.sort.filetype");
            when Files.Settings.Sort_By_Size =>
               return Files.Localization.Text ("settings.sort.size");
            when Files.Settings.Sort_By_Modified =>
               return Files.Localization.Text ("settings.sort.modified");
         end case;
      end Sort_Field_Text;

      function Sort_Field_Token (Field : Files.Settings.Sort_Field) return String is
      begin
         case Field is
            when Files.Settings.Sort_By_Name =>
               return "name";
            when Files.Settings.Sort_By_Filetype =>
               return "filetype";
            when Files.Settings.Sort_By_Size =>
               return "size";
            when Files.Settings.Sort_By_Modified =>
               return "modified";
         end case;
      end Sort_Field_Token;

      Theme : constant Render_Theme :=
        (if Settings.High_Contrast_Theme then High_Contrast_Theme else Default_Theme);

      function Filetype_Detail
        (Item : Files.File_System.Directory_Item)
         return UString
      is
      begin
         case Item.Kind is
            when Files.Types.Directory_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.directory"));
            when Files.Types.Symlink_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.symlink"));
            when Files.Types.Executable_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.executable"));
            when Files.Types.Regular_File_Item =>
               if To_String (Item.Filetype) = "text/plain" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.text"));
               elsif To_String (Item.Filetype) = "text/markdown" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.markdown"));
               elsif To_String (Item.Filetype) = "text/x-ada" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.source.ada"));
               elsif To_String (Item.Filetype) = "application/json" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.source.json"));
               elsif To_String (Item.Filetype) = "application/xml" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.source.xml"));
               elsif To_String (Item.Filetype) = "image/png" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.image.png"));
               elsif To_String (Item.Filetype) = "image/jpeg" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.image.jpeg"));
               elsif To_String (Item.Filetype) = "application/pdf" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.document.pdf"));
               elsif To_String (Item.Filetype) =
                 "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.document.word"));
               elsif To_String (Item.Filetype) =
                 "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.document.spreadsheet"));
               elsif To_String (Item.Filetype) = "application/zip"
                 or else To_String (Item.Filetype) = "application/x-tar"
                 or else To_String (Item.Filetype) = "application/gzip-tar"
                 or else To_String (Item.Filetype) = "application/gzip"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.archive"));
               elsif To_String (Item.Filetype) = "audio/mpeg"
                 or else To_String (Item.Filetype) = "audio/wav"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.audio"));
               elsif To_String (Item.Filetype) = "video/mp4" then
                  return To_Unbounded_String (Files.Localization.Text ("info.kind.video"));
               end if;
            when Files.Types.Other_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.other"));
            when Files.Types.Unknown_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.kind.unknown"));
         end case;

         return To_Unbounded_String (Files.Localization.Text ("info.kind.file"));
      end Filetype_Detail;

      function Filetype_Extra
        (Item : Files.File_System.Directory_Item)
         return UString
      is
         Type_Name : constant String := To_String (Item.Filetype);

         function Token_Detail (Token : String) return UString is
            Separator : constant Natural := Ada.Strings.Fixed.Index (Token, "|");
         begin
            if Separator <= Token'First or else Separator >= Token'Last then
               return Null_Unbounded_String;
            end if;

            declare
               Key   : constant String := Token (Token'First .. Separator - 1);
               Value : constant String := Token (Separator + 1 .. Token'Last);
               Second : constant Natural := Ada.Strings.Fixed.Index (Value, "|");
            begin
               if Key = "executable.format" then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.executable.format.prefix")
                       & Files.Localization.Text ("info.extra.executable.format." & Value)
                       & Files.Localization.Text ("info.extra.executable.format.suffix"));
               elsif Key = "directory.count" then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.directory.count.prefix")
                       & Value
                       & Files.Localization.Text ("info.extra.directory.count.suffix"));
               elsif Key = "text.lines" then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.text.lines.prefix")
                       & Value
                       & Files.Localization.Text ("info.extra.text.lines.suffix"));
               elsif Key = "text.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Files.Localization.Text ("info.extra.text.lines.prefix")
                          & Lines
                          & Files.Localization.Text ("info.extra.text.lines.suffix")
                          & " "
                          & Files.Localization.Text ("info.extra.encoding.prefix")
                          & Files.Localization.Text ("info.extra.encoding." & Encoding)
                          & Files.Localization.Text ("info.extra.encoding.suffix"));
                  end;
               elsif Key = "markdown.lines" then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.markdown.lines.prefix")
                       & Value
                       & Files.Localization.Text ("info.extra.markdown.lines.suffix"));
               elsif Key = "markdown.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Files.Localization.Text ("info.extra.markdown.lines.prefix")
                          & Lines
                          & Files.Localization.Text ("info.extra.markdown.lines.suffix")
                          & " "
                          & Files.Localization.Text ("info.extra.encoding.prefix")
                          & Files.Localization.Text ("info.extra.encoding." & Encoding)
                          & Files.Localization.Text ("info.extra.encoding.suffix"));
                  end;
               elsif Key = "image.dimensions" then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.image.dimensions.prefix")
                       & Value
                       & Files.Localization.Text ("info.extra.image.dimensions.suffix"));
               elsif Key = "symlink.target" then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.symlink.target.prefix")
                       & Value
                       & Files.Localization.Text ("info.extra.symlink.target.suffix"));
               elsif Key = "document.kind" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.document." & Value));
               elsif Key = "document.pdf.pages" then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.document.pdf.pages.prefix")
                       & Value
                       & Files.Localization.Text ("info.extra.document.pdf.pages.suffix"));
               elsif Key = "archive.format" then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.archive.format.prefix")
                       & Files.Localization.Text ("info.extra.archive.format." & Value)
                       & Files.Localization.Text ("info.extra.archive.format.suffix"));
               elsif Key = "archive.zip.entries" or else Key = "archive.gzip-tar.entries" then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.archive.entries.prefix")
                       & Value
                       & Files.Localization.Text ("info.extra.archive.entries.suffix"));
               elsif Key = "office.docx.entries" then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.office.docx.prefix")
                       & Value
                       & Files.Localization.Text ("info.extra.office.entries.suffix"));
               elsif Key = "office.xlsx.entries" then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.office.xlsx.prefix")
                       & Value
                       & Files.Localization.Text ("info.extra.office.entries.suffix"));
               elsif Key = "media.kind" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.media." & Value));
               elsif Key = "source.ada.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Files.Localization.Text ("info.extra.source.ada.prefix")
                          & Lines
                          & Files.Localization.Text ("info.extra.source.lines.suffix")
                          & " "
                          & Files.Localization.Text ("info.extra.encoding.prefix")
                          & Files.Localization.Text ("info.extra.encoding." & Encoding)
                          & Files.Localization.Text ("info.extra.encoding.suffix"));
                  end;
               elsif Key = "source.json.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Files.Localization.Text ("info.extra.source.json.prefix")
                          & Lines
                          & Files.Localization.Text ("info.extra.source.lines.suffix")
                          & " "
                          & Files.Localization.Text ("info.extra.encoding.prefix")
                          & Files.Localization.Text ("info.extra.encoding." & Encoding)
                          & Files.Localization.Text ("info.extra.encoding.suffix"));
                  end;
               elsif Key = "source.xml.lines_encoding" and then Second > Value'First then
                  declare
                     Lines    : constant String := Value (Value'First .. Second - 1);
                     Encoding : constant String := Value (Second + 1 .. Value'Last);
                  begin
                     return
                       To_Unbounded_String
                         (Files.Localization.Text ("info.extra.source.xml.prefix")
                          & Lines
                          & Files.Localization.Text ("info.extra.source.lines.suffix")
                          & " "
                          & Files.Localization.Text ("info.extra.encoding.prefix")
                          & Files.Localization.Text ("info.extra.encoding." & Encoding)
                          & Files.Localization.Text ("info.extra.encoding.suffix"));
                  end;
               end if;
            end;

            return Null_Unbounded_String;
         end Token_Detail;

         function Extension_Detail
           (Name : String)
            return String
         is
            Extension : constant String := Files.File_Types.Extension_Of (Name);
         begin
            if Extension = "" then
               return Files.Localization.Text ("info.extra.file");
            end if;

            return
              Files.Localization.Text ("info.extra.extension.prefix")
              & Extension
              & Files.Localization.Text ("info.extra.extension.suffix");
         end Extension_Detail;
      begin
         if Length (Item.Filetype_Extra) > 0 then
            declare
               Detail : constant UString := Token_Detail (To_String (Item.Filetype_Extra));
            begin
               if Length (Detail) > 0 then
                  return Detail;
               end if;
            end;
         end if;

         case Item.Kind is
            when Files.Types.Directory_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.directory"));
            when Files.Types.Symlink_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.symlink"));
            when Files.Types.Executable_Item =>
               if Item.Size_Available then
                  return
                    To_Unbounded_String
                      (Files.Localization.Text ("info.extra.executable.size.prefix")
                       & Ada.Strings.Fixed.Trim (Long_Long_Integer'Image (Item.Size), Ada.Strings.Both)
                       & Files.Localization.Text ("info.extra.executable.size.suffix"));
               else
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.executable"));
               end if;
            when Files.Types.Other_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.other"));
            when Files.Types.Unknown_Item =>
               return To_Unbounded_String (Files.Localization.Text ("info.extra.unknown"));
            when Files.Types.Regular_File_Item =>
               if Type_Name = "text/plain" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.text"));
               elsif Type_Name = "text/markdown" then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.markdown"));
               elsif Type_Name'Length >= 6
                 and then Type_Name (Type_Name'First .. Type_Name'First + 5) = "image/"
               then
                  return To_Unbounded_String (Files.Localization.Text ("info.extra.image"));
               elsif Type_Name = "application/octet-stream" then
                  return To_Unbounded_String (Extension_Detail (To_String (Item.Name)));
               end if;
         end case;

         return To_Unbounded_String (Extension_Detail (To_String (Item.Name)));
      end Filetype_Extra;

      function Root_Display_Label
        (Path  : String;
         Label : String)
         return String is
      begin
         declare
            Separator : constant Natural := Ada.Strings.Fixed.Index (Label, "|");
         begin
            if Separator > Label'First then
               declare
                  Key       : constant String := Label (Label'First .. Separator - 1);
                  Tail      : constant String := Label (Separator + 1 .. Label'Last);
                  Second    : constant Natural := Ada.Strings.Fixed.Index (Tail, "|");
                  Value_End : constant Natural :=
                    (if Second = 0 then Tail'Last else Second - 1);
                  Value     : constant String := Tail (Tail'First .. Value_End);
               begin
                  if Second = 0 then
                     return
                       Files.Localization.Text (Key & ".prefix")
                       & Value
                       & Files.Localization.Text (Key & ".suffix");
                  else
                     declare
                        Detail : constant String := Tail (Second + 1 .. Tail'Last);
                     begin
                        return
                          Files.Localization.Text (Key & ".prefix")
                          & Value
                          & Files.Localization.Text ("root.detail.prefix")
                          & Detail
                          & Files.Localization.Text ("root.detail.suffix")
                          & Files.Localization.Text (Key & ".suffix");
                     end;
                  end if;
               end;
            end if;
         end;

         if Label'Length >= 5
           and then Label (Label'First .. Label'First + 4) = "root."
         then
            return Files.Localization.Text (Label);
         elsif Label /= "" then
            return Label;
         else
            return Path;
         end if;
      end Root_Display_Label;
   begin
      Snapshot.Current_Path := To_Unbounded_String (Files.Model.Current_Path (Model));
      Snapshot.View_Mode := Files.Model.View_Mode_Of (Model);
      Snapshot.Item_Count := Files.Model.Item_Count (Model);
      Snapshot.Visible_Count := Files.Model.Visible_Count (Model);
      Snapshot.Selected_Count := Files.Model.Selected_Count (Model);
      Snapshot.Filter_Text := To_Unbounded_String (Files.Model.Filter_Text (Model));
      Snapshot.Last_Error_Key := To_Unbounded_String (Files.Model.Last_Error_Key (Model));
      Snapshot.Focus := Files.Model.Focus (Model);
      Snapshot.Text_Cursor_Position := Files.Model.Text_Cursor_Position (Model);
      Snapshot.Path_Input_Text := To_Unbounded_String (Files.Model.Path_Input_Text (Model));
      Snapshot.Path_Input_Valid := Files.Model.Path_Input_Is_Valid (Model);
      Snapshot.Path_Input_Error_Key := To_Unbounded_String (Files.Model.Path_Input_Error_Key (Model));
      Snapshot.Rename_Active := Files.Model.Rename_Is_Active (Model);
      Snapshot.Rename_Text := To_Unbounded_String (Files.Model.Rename_Text (Model));
      Snapshot.Temporary_Item_Active := Files.Model.Temporary_Item_Is_Active (Model);
      Snapshot.Temporary_Item_Name := To_Unbounded_String (Files.Model.Temporary_Item_Name (Model));
      Snapshot.Info_Pane_Open := Files.Model.Info_Pane_Is_Open (Model);
      Snapshot.Settings_Pane_Open := Files.Model.Settings_Pane_Is_Open (Model);
      Snapshot.Settings_Default_View := To_Unbounded_String (View_Mode_Text (Settings.Default_View));
      Snapshot.Settings_Default_View_Token := To_Unbounded_String (View_Mode_Token (Settings.Default_View));
      Snapshot.Settings_Hidden_Files := To_Unbounded_String (Boolean_Text (Settings.Show_Hidden_Files));
      Snapshot.Settings_Hidden_Files_Token := To_Unbounded_String (Boolean_Token (Settings.Show_Hidden_Files));
      Snapshot.Settings_Sort :=
        To_Unbounded_String
          (Sort_Field_Text (Settings.Sort_Field_Value)
           & Files.Localization.Text
             ((if Settings.Sort_Ascending then "settings.sort.ascending" else "settings.sort.descending")));
      Snapshot.Settings_Sort_Field_Token := To_Unbounded_String (Sort_Field_Token (Settings.Sort_Field_Value));
      Snapshot.Settings_Sort_Dirs := To_Unbounded_String (Boolean_Text (Settings.Sort_Directories_First));
      Snapshot.Settings_Sort_Dirs_Token := To_Unbounded_String (Boolean_Token (Settings.Sort_Directories_First));
      Snapshot.Settings_Sort_Ascending := To_Unbounded_String (Boolean_Text (Settings.Sort_Ascending));
      Snapshot.Settings_Sort_Ascending_Token := To_Unbounded_String (Boolean_Token (Settings.Sort_Ascending));
      Snapshot.Settings_High_Contrast := To_Unbounded_String (Boolean_Text (Settings.High_Contrast_Theme));
      Snapshot.Settings_High_Contrast_Token := To_Unbounded_String (Boolean_Token (Settings.High_Contrast_Theme));
      Snapshot.Settings_Icon_Theme := Settings.Icon_Theme_Name;
      Snapshot.Settings_Filetypes :=
        To_Unbounded_String (Natural_Text (Natural (Settings.Extension_Filetypes.Length)));
      Snapshot.Settings_Icons :=
        To_Unbounded_String (Natural_Text (Natural (Settings.Icon_Mappings.Length)));
      Snapshot.Settings_Open_Actions :=
        To_Unbounded_String (Natural_Text (Natural (Settings.Open_Actions.Length)));
      if Snapshot.Settings_Pane_Open then
         declare
            Draft : constant Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
         begin
            if Length (Draft.Default_View_Mode) > 0 then
               Snapshot.Settings_Default_View := Draft.Default_View_Mode;
               Snapshot.Settings_Default_View_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Default_View_Mode)));
               Snapshot.Settings_Hidden_Files := Draft.Show_Hidden_Files;
               Snapshot.Settings_Hidden_Files_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Show_Hidden_Files)));
               Snapshot.Settings_Sort_Dirs := Draft.Sort_Directories_First;
               Snapshot.Settings_Sort_Dirs_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Sort_Directories_First)));
               Snapshot.Settings_Sort := Draft.Sort_Field_Value;
               Snapshot.Settings_Sort_Field_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Sort_Field_Value)));
               Snapshot.Settings_Sort_Ascending := Draft.Sort_Ascending;
               Snapshot.Settings_Sort_Ascending_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.Sort_Ascending)));
               Snapshot.Settings_High_Contrast := Draft.High_Contrast_Theme;
               Snapshot.Settings_High_Contrast_Token :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Draft.High_Contrast_Theme)));
               Snapshot.Settings_Icon_Theme := Draft.Icon_Theme_Name;
               Snapshot.Settings_Filetype_Extension := Draft.Filetype_Extension;
               Snapshot.Settings_Filetype_Value := Draft.Filetype_Value;
               Snapshot.Settings_Icon_Filetype := Draft.Icon_Filetype;
               Snapshot.Settings_Icon_Value := Draft.Icon_Value;
               Snapshot.Settings_Open_Action_Token := Draft.Open_Action_Token;
               Snapshot.Settings_Open_Action_Command := Draft.Open_Action_Command;
               Snapshot.Settings_Filetypes :=
                 To_Unbounded_String
                   (Natural_Text (Paired_Row_Count (Draft.Filetype_Keys, Draft.Filetype_Values)));
               Snapshot.Settings_Icons :=
                 To_Unbounded_String
                   (Natural_Text (Paired_Row_Count (Draft.Icon_Keys, Draft.Icon_Values)));
               Snapshot.Settings_Open_Actions :=
                 To_Unbounded_String
                   (Natural_Text (Paired_Row_Count (Draft.Open_Action_Keys, Draft.Open_Action_Commands)));
               Snapshot.Settings_Draft_Valid := Draft.Valid;
               Snapshot.Settings_Draft_Error := Draft.Error_Key;
            end if;

            Snapshot.Settings_Field_Index := Files.Model.Settings_Field_Index (Model);
         end;
      end if;
      case Snapshot.Settings_Field_Index is
         when 1 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.default_view"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.default_view"));
         when 2 | 3 | 5 | 6 =>
            Snapshot.Settings_Field_Help := To_Unbounded_String (Files.Localization.Text ("settings.help.boolean"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.boolean"));
         when 4 =>
            Snapshot.Settings_Field_Help := To_Unbounded_String (Files.Localization.Text ("settings.help.sort"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.sort"));
         when 7 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.icon_theme"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.icon_theme"));
         when 8 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.filetype_extension"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when 9 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.filetype_value"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when 10 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.icon_filetype"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when 11 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.icon_value"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when 12 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.open_action_token"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when 13 =>
            Snapshot.Settings_Field_Help :=
              To_Unbounded_String (Files.Localization.Text ("settings.help.open_action_command"));
            Snapshot.Settings_Control_Options :=
              To_Unbounded_String (Files.Localization.Text ("settings.options.mapping"));
         when others =>
            Snapshot.Settings_Field_Help := Null_Unbounded_String;
            Snapshot.Settings_Control_Options := Null_Unbounded_String;
      end case;
      Snapshot.Info_Pane_Scroll_Lines := Files.Model.Info_Pane_Scroll_Lines (Model);
      Snapshot.Main_View_Scroll_Lines := Files.Model.Main_View_Scroll_Lines (Model);
      Snapshot.Settings_Can_Save := Files.Commands.Is_Enabled (Files.Commands.Save_Settings_Command, Model);
      Snapshot.Settings_Can_Reset := Files.Commands.Is_Enabled (Files.Commands.Reset_Settings_Command, Model);
      Snapshot.Settings_Can_Import := Files.Commands.Is_Enabled (Files.Commands.Import_Settings_Command, Model);
      Snapshot.Settings_Can_Export := Files.Commands.Is_Enabled (Files.Commands.Export_Settings_Command, Model);
      Snapshot.Theme_Name := Theme.Name;
      Snapshot.Theme_High_Contrast := Theme.High_Contrast;
      Snapshot.Theme_Focus_Ring := Theme.Focus_Ring;
      Snapshot.Root_Selector_Open := Files.Model.Root_Selector_Is_Open (Model);
      Snapshot.Root_Selected_Index := Files.Model.Root_Selected_Index (Model);
      Snapshot.Command_Palette_Open := Files.Model.Command_Palette_Is_Open (Model);
      Snapshot.Command_Palette_Query := To_Unbounded_String (Files.Model.Command_Palette_Query (Model));

      for Id in Files.Commands.Registered_Command_Id loop
         Snapshot.Command_Enabled (Id) := Files.Commands.Is_Enabled (Id, Model);
      end loop;

      for Index in 1 .. Files.Model.Root_Count (Model) loop
         declare
            Root_Path  : constant String := Files.Model.Root_Path (Model, Index);
            Root_Label : constant String := Files.Model.Root_Label (Model, Index);
         begin
            Snapshot.Root_Paths.Append (To_Unbounded_String (Root_Path));
            Snapshot.Root_Labels.Append (To_Unbounded_String (Root_Display_Label (Root_Path, Root_Label)));
         end;
      end loop;

      if Snapshot.Command_Palette_Open then
         declare
            Palette_Results : constant Files.Command_Palette.Result_Vectors.Vector :=
              Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Model), Model);
            Selected_Index  : Natural := Files.Model.Command_Palette_Selected_Index (Model);
            Result_Offset   : Natural := Files.Model.Command_Palette_Result_Offset (Model);
         begin
            if Selected_Index = 0 and then not Palette_Results.Is_Empty then
               Selected_Index := 1;
            elsif Selected_Index > Natural (Palette_Results.Length) then
               Selected_Index := (if Palette_Results.Is_Empty then 0 else 1);
            end if;

            Snapshot.Command_Palette_Selected_Index := Selected_Index;
            if Palette_Results.Is_Empty then
               Result_Offset := 0;
            elsif Result_Offset >= Natural (Palette_Results.Length) then
               Result_Offset := Natural (Palette_Results.Length) - 1;
            end if;
            Snapshot.Command_Palette_Result_Offset := Result_Offset;

            for Index in 1 .. Natural (Palette_Results.Length) loop
               declare
                  Item : constant Files.Command_Palette.Result_Entry :=
                    Palette_Results.Element (Positive (Index));
                  Primary_Shortcut : constant String :=
                    Files.Commands.Shortcut_Text (Files.Commands.Shortcut_For (Item.Command));
                  Secondary_Shortcut : constant String :=
                    Files.Commands.Shortcut_Text (Files.Commands.Secondary_Shortcut_For (Item.Command));
                  Display_Shortcut : constant String :=
                    (if Primary_Shortcut = "" then Secondary_Shortcut
                     elsif Secondary_Shortcut = "" then Primary_Shortcut
                     else Primary_Shortcut & " / " & Secondary_Shortcut);
               begin
                  Snapshot.Command_Palette_Results.Append
                    (Command_Result_Snapshot'
                       (Identifier => Item.Identifier,
                        Label      => Item.Label,
                        Description => Item.Description,
                        Shortcut_Text => To_Unbounded_String (Display_Shortcut),
                        Enabled    => Item.Enabled,
                        Selected   => Index = Selected_Index));
               end;
            end loop;
         end;
      end if;

      for Index in 1 .. Files.Model.Visible_Count (Model) loop
         declare
            Item : constant Files.File_System.Directory_Item := Files.Model.Visible_Item (Model, Index);
         begin
            Snapshot.Items.Append
              (Item_Snapshot'
                 (Name               => Item.Name,
                  Filetype           => Item.Filetype,
                  Filetype_Detail    => Filetype_Detail (Item),
                  Icon_Id            => Item.Icon_Id,
                  Kind               => Item.Kind,
                  Size_Available     => Item.Size_Available,
                  Size               => Item.Size,
                  Creation_Available => Item.Creation_Available,
                  Creation_Time      => Item.Creation_Time,
                  Modified_Available => Item.Modified_Available,
                  Modified_Time      => Item.Modified_Time,
                  Permissions        => Item.Permissions,
                  Filetype_Extra     => Filetype_Extra (Item),
                  Metadata_Error     => Item.Metadata_Error,
                  Error_Key          => Item.Error_Key,
                  Selected           => Files.Model.Is_Selected (Model, Index),
                  Visible_Index      => Index));
         end;
      end loop;

      if Files.Model.Selected_Count (Model) > 0 then
         declare
            Items : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
         begin
            if Items.Is_Empty then
               declare
                  Item : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
               begin
                  Snapshot.Selected_Info.Append
                    (Info_Snapshot'
                       (Name               => Item.Name,
                        Filetype           => Item.Filetype,
                        Size_Available     => Item.Size_Available,
                        Size               => Item.Size,
                        Creation_Available => Item.Creation_Available,
                        Creation_Time      => Item.Creation_Time,
                        Modified_Available => Item.Modified_Available,
                        Modified_Time      => Item.Modified_Time,
                        Permissions        => Item.Permissions,
                        Metadata_Error     => Item.Metadata_Error,
                        Error_Key          => Item.Error_Key,
                        Filetype_Detail    => Filetype_Detail (Item),
                        Filetype_Extra     => Filetype_Extra (Item)));
               end;
            else
               for Item of Items loop
                  Snapshot.Selected_Info.Append
                    (Info_Snapshot'
                       (Name               => Item.Name,
                        Filetype           => Item.Filetype,
                        Size_Available     => Item.Size_Available,
                        Size               => Item.Size,
                        Creation_Available => Item.Creation_Available,
                        Creation_Time      => Item.Creation_Time,
                        Modified_Available => Item.Modified_Available,
                        Modified_Time      => Item.Modified_Time,
                        Permissions        => Item.Permissions,
                        Metadata_Error     => Item.Metadata_Error,
                        Error_Key          => Item.Error_Key,
                        Filetype_Detail    => Filetype_Detail (Item),
                        Filetype_Extra     => Filetype_Extra (Item)));
               end loop;
            end if;
         end;
      end if;

      return Snapshot;
   end Build_Snapshot;

   function Calculate_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Layout_Metrics
   is
      Toolbar    : constant Natural := Saturating_Multiply (Line_Height, 2);
      Bottom     : constant Natural := Line_Height;
      Used_Y     : constant Natural := Saturating_Add (Toolbar, Bottom);
      Main_H     : constant Natural := (if Height > Used_Y then Height - Used_Y else 0);
      Pane_W     : constant Natural := (if Snapshot.Info_Pane_Open then Width / 4 else 0);
      Main_W     : constant Natural := (if Width > Pane_W then Width - Pane_W else 0);
      Command_W  : constant Natural := Scaled_Down (Width, 8, 10);
      Command_H  : constant Natural := Scaled_Down (Height, 8, 10);
      Command_X  : constant Natural := (if Width > Command_W then (Width - Command_W) / 2 else 0);
      Command_Y  : constant Natural :=
        (if Height > Command_H then Natural'Min (Line_Height, Height - Command_H) else 0);
   begin
      return
        (Width             => Width,
         Height            => Height,
         Toolbar_Height    => Toolbar,
         Bottom_Bar_Height => Bottom,
         Main_X            => 0,
         Main_Y            => Toolbar,
         Main_Width        => Main_W,
         Main_Height       => Main_H,
         Info_Pane_Width   => Pane_W,
         Command_X         => Command_X,
         Command_Y         => Command_Y,
         Command_Width     => Command_W,
         Command_Height    => Command_H);
   end Calculate_Layout;

   function Calculate_Item_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Item_Layout_Vectors.Vector
   is
      Result : Item_Layout_Vectors.Vector;
      Main_View : constant Main_View_Layout :=
        Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
      Scroll_Pixels : constant Natural := Main_View.Scroll_Pixels;

      function Saturating_Subtract (Left : Natural; Right : Natural) return Natural is
      begin
         if Left > Right then
            return Left - Right;
         else
            return 0;
         end if;
      end Saturating_Subtract;

      function Columns_For (Main_Width : Natural; Cell_Width : Positive) return Positive is
      begin
         if Main_Width < Cell_Width then
            return 1;
         else
            return Positive (Main_Width / Cell_Width);
         end if;
      end Columns_For;

      procedure Append_Grid_Item
        (Index     : Positive;
         Cell_W    : Positive;
         Cell_H    : Positive;
         Icon_Size : Positive;
         Large     : Boolean)
      is
         Columns     : constant Positive := Columns_For (Layout.Main_Width, Cell_W);
         Offset      : constant Natural := Natural (Index - 1);
         Column      : constant Natural := Offset mod Columns;
         Row         : constant Natural := Offset / Columns;
         Cell_Offset : constant Natural := Column * Cell_W;
         Row_Offset  : constant Natural := Saturating_Multiply (Row, Cell_H);
         Hidden_Px   : constant Natural :=
           (if Row_Offset < Scroll_Pixels then Natural'Min (Cell_H, Scroll_Pixels - Row_Offset) else 0);
         Visible_Row : constant Natural := Saturating_Subtract (Row_Offset, Scroll_Pixels);
         Cell_X      : constant Natural := Saturating_Add (Layout.Main_X, Cell_Offset);
         Cell_Y      : constant Natural := Saturating_Add (Layout.Main_Y, Visible_Row);
         Cell_Width  : constant Natural :=
           (if Layout.Main_Width > Cell_Offset
            then Natural'Min (Cell_W, Layout.Main_Width - Cell_Offset)
            else 0);
         Cell_Height : constant Natural :=
           (if Hidden_Px = Cell_H
            then 0
            elsif Layout.Main_Height > Visible_Row
            then Natural'Min (Cell_H - Hidden_Px, Layout.Main_Height - Visible_Row)
            else 0);
         Draw_Icon   : constant Natural := Natural'Min (Icon_Size, Natural'Min (Cell_Width, Cell_Height));
         Used_X      : constant Natural :=
           (if Large then 0 else Natural'Min (Cell_Width, Saturating_Add (Draw_Icon, 4)));
         Icon_X      : constant Natural :=
           (if Large then Saturating_Add (Cell_X, (Cell_Width - Draw_Icon) / 2) else Cell_X);
         Icon_Y      : constant Natural := Cell_Y;
         Text_X      : constant Natural := (if Large then Cell_X else Saturating_Add (Cell_X, Used_X));
         Text_Y      : constant Natural := (if Large then Saturating_Add (Cell_Y, Draw_Icon) else Cell_Y);
      begin
         Result.Append
           (Item_Layout'
              (Visible_Index => Snapshot.Items.Element (Index).Visible_Index,
               X             => Cell_X,
               Y             => Cell_Y,
               Width         => Cell_Width,
               Height        => Cell_Height,
               Icon_X        => Icon_X,
               Icon_Y         => Icon_Y,
               Icon_Size      => Draw_Icon,
               Text_X         => Text_X,
               Text_Y         => Text_Y,
               Text_Width     => Saturating_Subtract (Cell_Width, Used_X),
               Name_X         => Text_X,
               Name_Width     => Saturating_Subtract (Cell_Width, Used_X),
               Modified_X     => 0,
               Modified_Width => 0,
               Size_X         => 0,
               Size_Width     => 0,
               Filetype_X     => 0,
               Filetype_Width => 0));
      end Append_Grid_Item;
   begin
      for Index in 1 .. Natural (Snapshot.Items.Length) loop
         case Snapshot.View_Mode is
            when Files.Types.Small_Icons | Files.Types.Large_Icons =>
               declare
                  Metrics : constant Item_Cell_Metrics :=
                    Metrics_For (Snapshot.View_Mode, Layout.Main_Width, Line_Height);
               begin
                  Append_Grid_Item
                    (Positive (Index),
                     Cell_W    => Positive (Metrics.Width),
                     Cell_H    => Positive (Metrics.Height),
                     Icon_Size => Positive (Metrics.Icon_Size),
                     Large     => Metrics.Large);
               end;
            when Files.Types.Details =>
               declare
                  Header_H   : constant Natural := Natural'Min (Line_Height, Layout.Main_Height);
                  Rows_Y     : constant Natural := Saturating_Add (Layout.Main_Y, Header_H);
                  Rows_H     : constant Natural := Saturating_Subtract (Layout.Main_Height, Header_H);
                  Row_Offset : constant Natural := Saturating_Multiply (Natural (Index - 1), Line_Height);
                  Hidden_Px  : constant Natural :=
                    (if Row_Offset < Scroll_Pixels
                     then Natural'Min (Line_Height, Scroll_Pixels - Row_Offset)
                     else 0);
                  Visible_Row : constant Natural := Saturating_Subtract (Row_Offset, Scroll_Pixels);
                  Row_Y      : constant Natural := Saturating_Add (Rows_Y, Visible_Row);
                  Row_H      : constant Natural :=
                    (if Hidden_Px = Line_Height
                     then 0
                     elsif Rows_H > Visible_Row
                     then Natural'Min (Line_Height - Hidden_Px, Rows_H - Visible_Row)
                     else 0);
                  Icon_Gap   : constant Natural := Saturating_Add (Line_Height, 4);
                  Content_X  : constant Natural := Saturating_Add (Layout.Main_X, Icon_Gap);
                  Available  : constant Natural := Saturating_Subtract (Layout.Main_Width, Icon_Gap);
                  Type_W     : constant Natural := Natural'Min (160, Available / 4);
                  Size_W     : constant Natural := Natural'Min (96, Available / 6);
                  Modified_W : constant Natural := Natural'Min (180, Available / 4);
                  Used_W     : constant Natural :=
                    Saturating_Add (Type_W, Saturating_Add (Size_W, Modified_W));
                  Name_W     : constant Natural := Saturating_Subtract (Available, Used_W);
                  Modified_X : constant Natural := Saturating_Add (Content_X, Name_W);
                  Size_X     : constant Natural := Saturating_Add (Modified_X, Modified_W);
                  Type_X     : constant Natural := Saturating_Add (Size_X, Size_W);
               begin
                  Result.Append
                    (Item_Layout'
                       (Visible_Index  => Snapshot.Items.Element (Positive (Index)).Visible_Index,
                        X              => Layout.Main_X,
                        Y              => Row_Y,
                        Width          => Layout.Main_Width,
                        Height         => Row_H,
                        Icon_X         => Layout.Main_X,
                        Icon_Y         => Row_Y,
                        Icon_Size      => Natural'Min (Line_Height, Row_H),
                        Text_X         => Content_X,
                        Text_Y         => Row_Y,
                        Text_Width     => Name_W,
                        Name_X         => Content_X,
                        Name_Width     => Name_W,
                        Modified_X     => Modified_X,
                        Modified_Width => Modified_W,
                        Size_X         => Size_X,
                        Size_Width     => Size_W,
                        Filetype_X     => Type_X,
                        Filetype_Width => Type_W));
               end;
         end case;
      end loop;

      return Result;
   end Calculate_Item_Layout;

   function Calculate_Main_View_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Main_View_Layout
   is
      Count        : constant Natural := Natural (Snapshot.Items.Length);
      Metrics      : constant Item_Cell_Metrics :=
        Metrics_For (Snapshot.View_Mode, Layout.Main_Width, Line_Height);
      Cell_W       : constant Natural := Metrics.Width;
      Cell_H       : constant Natural := Metrics.Height;
      Columns      : constant Natural :=
        (if Snapshot.View_Mode = Files.Types.Details or else Cell_W = 0
         then 1
         elsif Layout.Main_Width < Cell_W
         then 1
         else Natural'Max (1, Layout.Main_Width / Cell_W));
      Rows         : constant Natural := (if Count = 0 then 0 else 1 + (Count - 1) / Columns);
      Row_Content_H : constant Natural := Saturating_Multiply (Rows, Cell_H);
      Content_H    : constant Natural :=
        (if Snapshot.View_Mode = Files.Types.Details
         then Saturating_Add (Natural'Min (Line_Height, Layout.Main_Height), Row_Content_H)
         else Row_Content_H);
      Max_Scroll   : constant Natural := (if Content_H > Layout.Main_Height then Content_H - Layout.Main_Height else 0);
      Requested_Px : constant Natural := Saturating_Multiply (Snapshot.Main_View_Scroll_Lines, Line_Height);
      Scroll_Px    : constant Natural := Natural'Min (Requested_Px, Max_Scroll);
      Scroll_Lines : constant Natural := Scroll_Px / Line_Height;
      Bar_W        : constant Natural := Natural'Min (6, Layout.Main_Width);
      Visible      : constant Boolean :=
        Layout.Main_Height > 0
        and then Bar_W > 0
        and then Content_H > Layout.Main_Height;
      Thumb_H      : constant Natural :=
        (if Visible
         then Natural'Min
           (Layout.Main_Height,
            Natural'Max
              (Line_Height,
               Bounded_Product_Divide
                 (Value => Layout.Main_Height, Factor => Layout.Main_Height, Denominator => Content_H)))
         else 0);
      Track_H      : constant Natural :=
        (if Layout.Main_Height > Thumb_H then Layout.Main_Height - Thumb_H else 0);
      Thumb_Y      : constant Natural :=
        (if Visible and then Max_Scroll > 0
         then Saturating_Add
           (Layout.Main_Y,
            Bounded_Product_Divide (Value => Track_H, Factor => Scroll_Px, Denominator => Max_Scroll))
         else Layout.Main_Y);
   begin
      return
        (Content_Height    => Content_H,
         Scroll_Lines      => Scroll_Lines,
         Scroll_Pixels     => Scroll_Px,
         Scrollbar_Visible => Visible,
         Scrollbar_X       => (if Visible then Saturating_Add (Layout.Main_X, Layout.Main_Width - Bar_W) else 0),
         Scrollbar_Y       => (if Visible then Layout.Main_Y else 0),
         Scrollbar_Thumb_Y => (if Visible then Thumb_Y else 0),
         Scrollbar_Width   => (if Visible then Bar_W else 0),
         Scrollbar_Height  => Thumb_H);
   end Calculate_Main_View_Layout;

   function Item_At
     (Items : Item_Layout_Vectors.Vector;
      X     : Natural;
      Y     : Natural)
      return Natural is
   begin
      for Item of Items loop
         if Contains_Rectangle_Point
              (Item.X, Item.Y, Item.Width, Item.Height, X, Y)
         then
            return Item.Visible_Index;
         end if;
      end loop;

      return 0;
   end Item_At;

   function Calculate_Command_Palette_Layout
     (Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Command_Palette_Layout
   is
      Search_H  : constant Natural := Natural'Min (Line_Height, Layout.Command_Height);
      Results_Y : constant Natural := Saturating_Add (Layout.Command_Y, Search_H);
   begin
      return
        (X              => Layout.Command_X,
         Y              => Layout.Command_Y,
         Width          => Layout.Command_Width,
         Height         => Layout.Command_Height,
         Search_X       => Layout.Command_X,
         Search_Y       => Layout.Command_Y,
         Search_Width   => Layout.Command_Width,
         Search_Height  => Search_H,
         Results_X      => Layout.Command_X,
         Results_Y      => Results_Y,
         Results_Width  => Layout.Command_Width,
         Results_Height => (if Layout.Command_Height > Search_H then Layout.Command_Height - Search_H else 0),
         Row_Height     => Saturating_Multiply (Line_Height, 2));
   end Calculate_Command_Palette_Layout;

   function Calculate_Command_Result_Layout
     (Snapshot : View_Snapshot;
      Layout   : Command_Palette_Layout)
      return Command_Result_Layout_Vectors.Vector
   is
      Result : Command_Result_Layout_Vectors.Vector;
      Result_Count : constant Natural := Natural (Snapshot.Command_Palette_Results.Length);
      Visible_Rows : constant Natural := Visible_Row_Count (Layout.Results_Height, Layout.Row_Height);
      Max_Offset   : constant Natural :=
        (if Visible_Rows = 0 or else Result_Count <= Visible_Rows then 0 else Result_Count - Visible_Rows);
      Offset       : constant Natural := Natural'Min (Snapshot.Command_Palette_Result_Offset, Max_Offset);
   begin
      if not Snapshot.Command_Palette_Open or else Layout.Row_Height = 0 then
         return Result;
      end if;

      for Index in Offset + 1 .. Result_Count loop
         declare
            Result_Y : constant Natural :=
              Saturating_Add
                (Layout.Results_Y, Saturating_Multiply (Natural (Index - Offset - 1), Layout.Row_Height));
            Results_End_Y : constant Natural := Saturating_Add (Layout.Results_Y, Layout.Results_Height);
         begin
            exit when Result_Y >= Results_End_Y;
            declare
               Remaining : constant Natural := Results_End_Y - Result_Y;
               Row_H     : constant Natural := Natural'Min (Layout.Row_Height, Remaining);
            begin
               Result.Append
                 (Command_Result_Layout'
                    (Result_Index => Index,
                     X            => Layout.Results_X,
                     Y            => Result_Y,
                     Width        => Layout.Results_Width,
                     Height       => Row_H,
                     Selected     => Snapshot.Command_Palette_Results.Element (Positive (Index)).Selected,
                     Enabled      => Snapshot.Command_Palette_Results.Element (Positive (Index)).Enabled));
            end;
         end;
      end loop;

      return Result;
   end Calculate_Command_Result_Layout;

   function Command_Result_At
     (Rows : Command_Result_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Contains_Rectangle_Point
              (Row.X, Row.Y, Row.Width, Row.Height, X, Y)
         then
            return Row.Result_Index;
         end if;
      end loop;

      return 0;
   end Command_Result_At;

   function Calculate_Root_Selector_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Root_Selector_Layout
   is
      Preferred_Width : constant Natural := Natural'Max (Layout.Width / 5, Saturating_Multiply (Line_Height, 12));
      Dropdown_Width  : constant Natural := Natural'Min (Layout.Width, Preferred_Width);
      Wanted_Height   : constant Natural := Saturating_Multiply (Natural (Snapshot.Root_Paths.Length), Line_Height);
      Dropdown_Height : constant Natural := Natural'Min (Layout.Main_Height, Wanted_Height);
   begin
      if not Snapshot.Root_Selector_Open then
         return (others => <>);
      end if;

      return
        (X          => 0,
         Y          => Layout.Toolbar_Height,
         Width      => Dropdown_Width,
         Height     => Dropdown_Height,
         Row_Height => Line_Height);
   end Calculate_Root_Selector_Layout;

   function Calculate_Root_Path_Layout
     (Snapshot : View_Snapshot;
      Layout   : Root_Selector_Layout)
      return Root_Path_Layout_Vectors.Vector
   is
      Result       : Root_Path_Layout_Vectors.Vector;
      Root_Count   : constant Natural := Natural (Snapshot.Root_Paths.Length);
      Visible_Rows : constant Natural := Visible_Row_Count (Layout.Height, Layout.Row_Height);
      Start_Index  : Natural := 1;
      Selected_Index : Natural := Snapshot.Root_Selected_Index;
   begin
      if not Snapshot.Root_Selector_Open
        or else Layout.Row_Height = 0
        or else Root_Count = 0
      then
         return Result;
      end if;

      if Selected_Index > Root_Count then
         Selected_Index := Root_Count;
      end if;

      if Visible_Rows > 0 and then Selected_Index > Visible_Rows then
         Start_Index := Selected_Index - Visible_Rows + 1;
      end if;

      if Start_Index > Root_Count then
         Start_Index := Root_Count;
      end if;

      for Index in Start_Index .. Root_Count loop
         declare
            Row_Y : constant Natural :=
              Saturating_Add (Layout.Y, Saturating_Multiply (Natural (Index - Start_Index), Layout.Row_Height));
            Layout_End_Y : constant Natural := Saturating_Add (Layout.Y, Layout.Height);
         begin
            exit when Row_Y >= Layout_End_Y;
            declare
               Remaining : constant Natural := Layout_End_Y - Row_Y;
               Row_H     : constant Natural := Natural'Min (Layout.Row_Height, Remaining);
            begin
               Result.Append
                 (Root_Path_Layout'
                    (Root_Index => Index,
                     X          => Layout.X,
                     Y          => Row_Y,
                     Width      => Layout.Width,
                     Height     => Row_H,
                     Selected   => Index = Selected_Index));
            end;
         end;
      end loop;

      return Result;
   end Calculate_Root_Path_Layout;

   function Root_Path_At
     (Rows : Root_Path_Layout_Vectors.Vector;
      X    : Natural;
      Y    : Natural)
      return Natural is
   begin
      for Row of Rows loop
         if Contains_Rectangle_Point
              (Row.X, Row.Y, Row.Width, Row.Height, X, Y)
         then
            return Row.Root_Index;
         end if;
      end loop;

      return 0;
   end Root_Path_At;

   function Calculate_Info_Pane_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Layout_Metrics;
      Line_Height : Positive := 20)
      return Info_Pane_Layout
   is
      Pane_X        : constant Natural := Layout.Main_Width;
      Content_H     : constant Natural :=
        Saturating_Multiply
          (Saturating_Multiply (Natural (Snapshot.Selected_Info.Length), Info_Rows_Per_Item), Line_Height);
      Bar_W         : constant Natural := Natural'Min (6, Layout.Info_Pane_Width);
      Visible       : constant Boolean :=
        Snapshot.Info_Pane_Open
        and then Layout.Info_Pane_Width > 0
        and then Bar_W > 0
        and then Layout.Main_Height > 0
        and then Content_H > Layout.Main_Height;
      Thumb_H       : constant Natural :=
        (if Visible
         then Natural'Max
           (Line_Height,
            Bounded_Product_Divide
              (Value => Layout.Main_Height, Factor => Layout.Main_Height, Denominator => Content_H))
         else 0);
      Max_Scroll_Px : constant Natural :=
        (if Content_H > Layout.Main_Height then Content_H - Layout.Main_Height else 0);
      Requested_Px  : constant Natural := Saturating_Multiply (Snapshot.Info_Pane_Scroll_Lines, Line_Height);
      Scroll_Px     : constant Natural := Natural'Min (Requested_Px, Max_Scroll_Px);
      Scroll_Lines  : constant Natural := Scroll_Px / Line_Height;
      Track_H       : constant Natural := (if Layout.Main_Height > Thumb_H then Layout.Main_Height - Thumb_H else 0);
      Thumb_Y       : constant Natural :=
        (if Visible and then Max_Scroll_Px > 0
         then Saturating_Add
           (Layout.Main_Y,
            Bounded_Product_Divide (Value => Track_H, Factor => Scroll_Px, Denominator => Max_Scroll_Px))
         else Layout.Main_Y);
   begin
      if not Snapshot.Info_Pane_Open or else Layout.Info_Pane_Width = 0 then
         return (others => <>);
      end if;

      return
        (X                 => Pane_X,
         Y                 => Layout.Main_Y,
         Width             => Layout.Info_Pane_Width,
         Height            => Layout.Main_Height,
         Content_Height    => Content_H,
         Scroll_Lines      => Scroll_Lines,
         Scroll_Pixels     => Scroll_Px,
         Scrollbar_Visible => Visible,
         Scrollbar_X       => (if Visible then Saturating_Add (Pane_X, Layout.Info_Pane_Width - Bar_W) else 0),
         Scrollbar_Y       => (if Visible then Layout.Main_Y else 0),
         Scrollbar_Thumb_Y => (if Visible then Thumb_Y else 0),
         Scrollbar_Width   => (if Visible then Bar_W else 0),
         Scrollbar_Height  => (if Visible then Natural'Min (Thumb_H, Layout.Main_Height) else 0));
   end Calculate_Info_Pane_Layout;

   function Build_Frame_Commands
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20;
      Hover_X     : Natural := 0;
      Hover_Y     : Natural := 0;
      Has_Hover   : Boolean := False;
      Pressed_X   : Natural := 0;
      Pressed_Y   : Natural := 0;
      Has_Press   : Boolean := False)
      return Frame_Commands
   is
      Result        : Frame_Commands;
      Layout        : constant Layout_Metrics :=
        Calculate_Layout (Snapshot, Width, Height, Line_Height);
      Items         : constant Item_Layout_Vectors.Vector :=
        Calculate_Item_Layout (Snapshot, Layout, Line_Height);
      Main_View     : constant Main_View_Layout := Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
      Toolbar       : constant Files.UI.Toolbar_Layout := Files.UI.Calculate_Toolbar_Layout (Width);
      Bottom        : constant Files.UI.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (Width, Line_Height);
      Palette       : constant Command_Palette_Layout := Calculate_Command_Palette_Layout (Layout, Line_Height);
      Palette_Rows  : constant Command_Result_Layout_Vectors.Vector :=
        Calculate_Command_Result_Layout (Snapshot, Palette);
      Root_Selector : constant Root_Selector_Layout :=
        Calculate_Root_Selector_Layout (Snapshot, Layout, Line_Height);
      Root_Rows     : constant Root_Path_Layout_Vectors.Vector :=
        Calculate_Root_Path_Layout (Snapshot, Root_Selector);
      Info_Pane     : constant Info_Pane_Layout := Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height);
      Bottom_Y      : constant Natural :=
        (if Height > Layout.Bottom_Bar_Height then Height - Layout.Bottom_Bar_Height else 0);

      function Clipped_Size
        (Start : Natural;
         Size  : Natural;
         Limit : Natural)
         return Natural
      is
      begin
         if Start >= Limit or else Size = 0 then
            return 0;
         else
            return Natural'Min (Size, Limit - Start);
         end if;
      end Clipped_Size;

      procedure Add_Rect
        (X      : Natural;
         Y      : Natural;
         Rect_W : Natural;
         Rect_H : Natural;
         Color  : Render_Color)
      is
         Draw_W : constant Natural := Clipped_Size (X, Rect_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Rect_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 then
            Result.Rectangles.Append
              (Rectangle_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Color  => Color));
         end if;
      end Add_Rect;

      procedure Add_Text
        (X      : Natural;
         Y      : Natural;
         Text_W : Natural;
         Text_H : Natural;
         Text   : UString;
         Color  : Render_Color := Text_Color;
         Fit    : Boolean := False)
      is
         Draw_W   : constant Natural := Clipped_Size (X, Text_W, Layout.Width);
         Draw_H   : constant Natural := Clipped_Size (Y, Text_H, Layout.Height);
         Cell_W   : constant Positive := Positive'Max (1, Line_Height / 2);
         Capacity : constant Natural := Draw_W / Cell_W;
         Raw      : constant String := To_String (Text);

         function Is_UTF8_Continuation
           (Value : Character)
            return Boolean is
            Code : constant Natural := Character'Pos (Value);
         begin
            return Code >= 16#80# and then Code <= 16#BF#;
         end Is_UTF8_Continuation;

         function UTF8_Safe_Prefix_Length
           (Max_Bytes : Natural)
            return Natural
         is
            Limit : Natural := Natural'Min (Max_Bytes, Raw'Length);
         begin
            while Limit > 0
              and then Limit < Raw'Length
              and then Is_UTF8_Continuation (Raw (Raw'First + Limit))
            loop
               Limit := Limit - 1;
            end loop;

            return Limit;
         end UTF8_Safe_Prefix_Length;

         function UTF8_Safe_Prefix
           (Max_Bytes : Natural)
            return String
         is
            Prefix_Length : constant Natural := UTF8_Safe_Prefix_Length (Max_Bytes);
         begin
            if Prefix_Length = 0 then
               return "";
            end if;

            return Raw (Raw'First .. Raw'First + Prefix_Length - 1);
         end UTF8_Safe_Prefix;

         function Fitted_Text return UString is
         begin
            if Capacity = 0 then
               return Null_Unbounded_String;
            elsif Raw'Length <= Capacity then
               return Text;
            elsif Capacity < 3 then
               return To_Unbounded_String (UTF8_Safe_Prefix (Capacity));
            else
               return To_Unbounded_String (UTF8_Safe_Prefix (Capacity - 3) & "...");
            end if;
         end Fitted_Text;

         Fitted : constant UString := (if Fit then Fitted_Text else Text);
         Was_Truncated : constant Boolean := Fit and then Length (Fitted) < Raw'Length;
      begin
         if Draw_W > 0 and then Draw_H > 0 and then Length (Fitted) > 0 then
            Result.Text.Append
              (Text_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Text   => Fitted,
                  Color  => Color,
                  Truncated => Was_Truncated));
         end if;
      end Add_Text;

      procedure Add_Tooltip
        (X        : Natural;
         Y        : Natural;
         Tip_W    : Natural;
         Tip_H    : Natural;
         Text_Key : String)
      is
         Text : constant String := Files.Localization.Text (Text_Key);
         Draw_W : constant Natural := Clipped_Size (X, Tip_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Tip_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 and then Text'Length > 0 then
            Result.Tooltips.Append
              (Tooltip_Command'
                 (X      => X,
                  Y      => Y,
                  Width  => Draw_W,
                  Height => Draw_H,
                  Text   => To_Unbounded_String (Text)));
         end if;
      end Add_Tooltip;

      procedure Add_Accessibility_Node
        (Role        : Accessibility_Role;
         X           : Natural;
         Y           : Natural;
         Node_W      : Natural;
         Node_H      : Natural;
         Name        : UString;
         Description : UString := Null_Unbounded_String;
         Enabled     : Boolean := True;
         Selected    : Boolean := False;
         Focused     : Boolean := False)
      is
         Draw_W : constant Natural := Clipped_Size (X, Node_W, Layout.Width);
         Draw_H : constant Natural := Clipped_Size (Y, Node_H, Layout.Height);
      begin
         if Draw_W > 0 and then Draw_H > 0 then
            Result.Accessibility.Append
              (Accessibility_Node'
                 (Role        => Role,
                  X           => X,
                  Y           => Y,
                  Width       => Draw_W,
                  Height      => Draw_H,
                  Name        => Name,
                  Description => Description,
                  Enabled     => Enabled,
                  Selected    => Selected,
                  Focused     => Focused));
         end if;
      end Add_Accessibility_Node;

      function Localized (Key : String) return UString is
      begin
         return To_Unbounded_String (Files.Localization.Text (Key));
      end Localized;

      function Path_Input_Accessible_Description return UString is
      begin
         if Snapshot.Path_Input_Valid or else Length (Snapshot.Path_Input_Error_Key) = 0 then
            return Snapshot.Path_Input_Text;
         end if;

         return
           Snapshot.Path_Input_Text
           & To_Unbounded_String (" ")
           & Localized (To_String (Snapshot.Path_Input_Error_Key));
      end Path_Input_Accessible_Description;

      function Command_Result_Accessible_Description
        (Command : Command_Result_Snapshot)
         return UString
      is
         Result : UString := Command.Description;
      begin
         if Length (Command.Shortcut_Text) > 0 then
            Result := Result & To_Unbounded_String (" ") & Command.Shortcut_Text;
         end if;

         if not Command.Enabled then
            Result := Result & To_Unbounded_String (" ") & Localized ("accessibility.command_disabled");
         end if;

         return Result;
      end Command_Result_Accessible_Description;

      function Contains_Point
        (X        : Natural;
         Y        : Natural;
         Box_W    : Natural;
         Box_H    : Natural;
         Point_X  : Natural;
         Point_Y  : Natural)
         return Boolean
      is
      begin
         return Contains_Rectangle_Point (X, Y, Box_W, Box_H, Point_X, Point_Y);
      end Contains_Point;

      function Tooltip_At
        (Point_X : Natural;
         Point_Y : Natural)
         return UString
      is
      begin
         for Command of Result.Tooltips loop
            if Contains_Point (Command.X, Command.Y, Command.Width, Command.Height, Point_X, Point_Y) then
               return Command.Text;
            end if;
         end loop;

         return Null_Unbounded_String;
      end Tooltip_At;

      function Is_Pressed
        (X     : Natural;
         Y     : Natural;
         Box_W : Natural;
         Box_H : Natural)
         return Boolean is
      begin
         return Has_Press and then Contains_Point (X, Y, Box_W, Box_H, Pressed_X, Pressed_Y);
      end Is_Pressed;

      procedure Add_Border
        (X        : Natural;
         Y        : Natural;
         Border_W : Natural;
         Border_H : Natural;
         Color    : Render_Color)
      is
      begin
         if Border_W = 0 or else Border_H = 0 then
            return;
         end if;

         Add_Rect (X, Y, Border_W, 1, Color);
         Add_Rect (X, Y, 1, Border_H, Color);
         Add_Rect (X, Saturating_Add (Y, Border_H - 1), Border_W, 1, Color);
         Add_Rect (Saturating_Add (X, Border_W - 1), Y, 1, Border_H, Color);
      end Add_Border;

      procedure Add_Focus_Ring
        (X      : Natural;
         Y      : Natural;
         Ring_W : Natural;
         Ring_H : Natural) is
      begin
         if Ring_W = 0 or else Ring_H = 0 then
            return;
         end if;

         Add_Border (X, Y, Ring_W, Ring_H, Snapshot.Theme_Focus_Ring);
         if X > 0 and then Y > 0 then
            Add_Border
              (X - 1,
               Y - 1,
               Saturating_Add (Ring_W, 2),
               Saturating_Add (Ring_H, 2),
               Snapshot.Theme_Focus_Ring);
         end if;
      end Add_Focus_Ring;

      procedure Add_Drop_Shadow
        (X        : Natural;
         Y        : Natural;
         Shadow_W : Natural;
         Shadow_H : Natural)
      is
         Shadow_Offset : constant Natural := 3;
      begin
         if Shadow_W = 0 or else Shadow_H = 0 then
            return;
         end if;

         Add_Rect
           (Saturating_Add (X, Shadow_Offset),
            Saturating_Add (Y, Shadow_H),
            Shadow_W,
            Shadow_Offset,
            Pane_Color);
         Add_Rect
           (Saturating_Add (X, Shadow_W),
            Saturating_Add (Y, Shadow_Offset),
            Shadow_Offset,
            Shadow_H,
            Pane_Color);
      end Add_Drop_Shadow;

      procedure Add_Scrollbar
        (Track_X  : Natural;
         Track_Y  : Natural;
         Track_W  : Natural;
         Track_H  : Natural;
         Thumb_Y  : Natural;
         Thumb_H  : Natural) is
         Grip_W : constant Natural := (if Track_W > 2 then Track_W - 2 else 0);
         Grip_X : constant Natural := Saturating_Add (Track_X, 1);
         Mid_Y  : constant Natural := Saturating_Add (Thumb_Y, Thumb_H / 2);
      begin
         Add_Rect (Track_X, Track_Y, Track_W, Track_H, Border_Color);
         Add_Rect (Track_X, Thumb_Y, Track_W, Thumb_H, Selection_Color);
         Add_Border (Track_X, Thumb_Y, Track_W, Thumb_H, Border_Color);

         if Grip_W > 0 and then Thumb_H >= 7 then
            Add_Rect (Grip_X, Mid_Y - 2, Grip_W, 1, Muted_Text_Color);
            Add_Rect (Grip_X, Mid_Y, Grip_W, 1, Muted_Text_Color);
            Add_Rect (Grip_X, Saturating_Add (Mid_Y, 2), Grip_W, 1, Muted_Text_Color);
         end if;
      end Add_Scrollbar;

      procedure Add_Hover_Tooltip is
         Padding   : constant Natural := 6;
         Text      : constant UString := Tooltip_At (Hover_X, Hover_Y);
         Text_Len  : constant Natural := Length (Text);
         Text_W    : constant Natural :=
           Natural'Min (Natural'Max (160, Saturating_Multiply (Text_Len, 8)), 360);
         Tip_W     : constant Natural := Saturating_Add (Text_W, 2 * Padding);
         Tip_H     : constant Natural := Saturating_Add (Line_Height, 2 * Padding);
         Desired_X : constant Natural := Saturating_Add (Hover_X, 12);
         Desired_Y : constant Natural := Saturating_Add (Hover_Y, 18);
         Tip_X     : constant Natural :=
           (if Width > Saturating_Add (Tip_W, 4) then Natural'Min (Desired_X, Width - Tip_W - 4) else 0);
         Tip_Y     : constant Natural :=
           (if Height > Saturating_Add (Tip_H, 4) then Natural'Min (Desired_Y, Height - Tip_H - 4) else 0);
      begin
         if not Has_Hover or else Text_Len = 0 then
            return;
         end if;

         Add_Rect (Tip_X, Tip_Y, Tip_W, Tip_H, Overlay_Color);
         Add_Border (Tip_X, Tip_Y, Tip_W, Tip_H, Border_Color);
         Add_Text
           (Tip_X + Padding,
            Tip_Y + Padding,
            Text_W,
            Line_Height,
            Text,
            Text_Color);
      end Add_Hover_Tooltip;

      procedure Add_Toolbar_Glyph
        (Id      : Files.Commands.Registered_Command_Id;
         X       : Natural;
         Y       : Natural;
         Size    : Natural;
         Enabled : Boolean)
      is
         Color : constant Render_Color := (if Enabled then Text_Color else Disabled_Text_Color);
         Mark  : constant Natural := Natural'Max (1, Size / 5);

         function Scale (Numerator : Natural; Denominator : Positive) return Natural is
         begin
            return Bounded_Product_Divide (Size, Numerator, Denominator);
         end Scale;

         function X_Offset (Offset : Natural) return Natural is
         begin
            return Saturating_Add (X, Offset);
         end X_Offset;

         function Y_Offset (Offset : Natural) return Natural is
         begin
            return Saturating_Add (Y, Offset);
         end Y_Offset;
      begin
         if Size = 0 then
            return;
         end if;

         case Id is
            when Files.Commands.Select_Drive_Command =>
               Add_Rect (X, Y_Offset (Scale (1, 4)), Size, Scale (1, 2), Color);
               Add_Rect (X_Offset (Scale (1, 5)), Y, Scale (3, 5), Natural'Max (1, Scale (1, 4)), Color);
               Add_Rect (X_Offset (Scale (1, 5)), Y_Offset (Size - Mark), Mark, Mark, Border_Color);

            when Files.Commands.Navigate_Home_Command =>
               Add_Rect (X_Offset (Scale (1, 5)), Y_Offset (Scale (1, 2)), Scale (3, 5), Scale (1, 2), Color);
               Add_Rect (X_Offset (Scale (1, 3)), Y_Offset (Scale (1, 3)), Scale (1, 3), Scale (1, 3), Color);
               Add_Rect (X_Offset (Scale (1, 2)), Y, Mark, Natural'Max (1, Scale (1, 3)), Color);

            when Files.Commands.Navigate_Back_Command =>
               Add_Rect (X, Y_Offset (Scale (1, 2)), Size, Mark, Color);
               Add_Rect (X, Y_Offset (Scale (1, 2)), Scale (1, 3), Mark, Color);
               Add_Rect (X_Offset (Mark), Y_Offset (Scale (1, 3)), Mark, Scale (1, 3), Color);

            when Files.Commands.Navigate_Forward_Command =>
               Add_Rect (X, Y_Offset (Scale (1, 2)), Size, Mark, Color);
               Add_Rect (X_Offset (Scale (2, 3)), Y_Offset (Scale (1, 2)), Scale (1, 3), Mark, Color);
               Add_Rect
                 (X_Offset (Size - Natural'Min (Size, Saturating_Multiply (2, Mark))),
                  Y_Offset (Scale (1, 3)),
                  Mark,
                  Scale (1, 3),
                  Color);

            when Files.Commands.Create_File_Command =>
               Add_Rect (X_Offset (Scale (1, 5)), Y, Scale (3, 5), Size, Color);
               Add_Rect (X_Offset (Scale (1, 2)), Y_Offset (Scale (1, 4)), Mark, Scale (1, 2), Border_Color);
               Add_Rect (X_Offset (Scale (1, 3)), Y_Offset (Scale (1, 2)), Scale (1, 3), Mark, Border_Color);

            when Files.Commands.Delete_Selected_Items_Command =>
               Add_Rect (X_Offset (Scale (1, 5)), Y_Offset (Scale (1, 4)), Scale (3, 5), Scale (3, 4), Color);
               Add_Rect (X_Offset (Scale (1, 6)), Y, Scale (2, 3), Mark, Color);
               Add_Rect (X_Offset (Scale (1, 3)), Y_Offset (Scale (1, 2)), Mark, Scale (1, 3), Border_Color);
               Add_Rect (X_Offset (Scale (3, 5)), Y_Offset (Scale (1, 2)), Mark, Scale (1, 3), Border_Color);

            when others =>
               Add_Rect (X, Y, Size, Size, Color);
         end case;
      end Add_Toolbar_Glyph;

      procedure Add_Caret
        (X       : Natural;
         Y       : Natural;
         Field_W : Natural;
         Field_H : Natural)
      is
         Char_W : constant Positive := Positive'Max (1, Line_Height / 2);
         Raw_X  : constant Natural :=
           Saturating_Add
             (Saturating_Add (X, 4),
              Saturating_Multiply (Snapshot.Text_Cursor_Position, Char_W));
         Max_X  : constant Natural := (if Field_W > 2 then Saturating_Add (X, Field_W - 2) else X);
      begin
         if Field_W > 0 and then Field_H > 4 then
            Add_Rect
              (Natural'Min (Raw_X, Max_X),
               Saturating_Add (Y, 2),
               1,
               Field_H - 4,
               Border_Color);
         end if;
      end Add_Caret;

      procedure Add_Palette_Scrollbar is
         Result_Count : constant Natural := Natural (Snapshot.Command_Palette_Results.Length);
         Visible_Rows : constant Natural := Visible_Row_Count (Palette.Results_Height, Palette.Row_Height);
         Bar_W       : constant Natural := Natural'Min (6, Palette.Results_Width);
         Track_H     : constant Natural := Palette.Results_Height;
         Thumb_H     : Natural := 0;
         Thumb_Y     : Natural := Palette.Results_Y;
         Max_Offset  : Natural := 0;
      begin
         if not Snapshot.Command_Palette_Open
           or else Result_Count = 0
           or else Visible_Rows = 0
           or else Result_Count <= Visible_Rows
           or else Track_H = 0
         then
            return;
         end if;

         Max_Offset := Result_Count - Visible_Rows;
         Thumb_H :=
           Natural'Max
             (Palette.Row_Height,
              Bounded_Product_Divide (Value => Track_H, Factor => Visible_Rows, Denominator => Result_Count));
         Thumb_H := Natural'Min (Thumb_H, Track_H);

         if Max_Offset > 0 and then Track_H > Thumb_H then
            Thumb_Y :=
              Saturating_Add
                (Palette.Results_Y,
                 Bounded_Product_Divide
                   (Value       => Track_H - Thumb_H,
                    Factor      => Natural'Min (Snapshot.Command_Palette_Result_Offset, Max_Offset),
                    Denominator => Max_Offset));
         end if;

         Add_Scrollbar
           (Saturating_Add (Palette.Results_X, Palette.Results_Width - Bar_W),
            Palette.Results_Y,
            Bar_W,
            Track_H,
            Thumb_Y,
            Thumb_H);
      end Add_Palette_Scrollbar;

      function Icon_Color (Kind : Files.Types.Item_Kind) return Render_Color is
      begin
         case Kind is
            when Files.Types.Directory_Item =>
               return Icon_Directory_Color;
            when Files.Types.Executable_Item =>
               return Icon_Executable_Color;
            when Files.Types.Regular_File_Item | Files.Types.Symlink_Item | Files.Types.Other_Item =>
               return Icon_File_Color;
            when Files.Types.Unknown_Item =>
               return Icon_Unknown_Color;
         end case;
      end Icon_Color;

      function Icon_Asset_Directory return String is
      begin
         if To_String (Snapshot.Settings_Icon_Theme) = "files-high-contrast" then
            return "share/files/icons/high-contrast";
         else
            return "share/files/icons";
         end if;
      end Icon_Asset_Directory;

      function Icon_Theme_Name return String is
      begin
         if Length (Snapshot.Settings_Icon_Theme) > 0 then
            return To_String (Snapshot.Settings_Icon_Theme);
         else
            return "files-basic";
         end if;
      end Icon_Theme_Name;

      function Is_Bundled_Icon (Name : String) return Boolean is
      begin
         return
           Name = "folder"
           or else Name = "text"
           or else Name = "image"
           or else Name = "executable"
           or else Name = "link"
           or else Name = "unknown"
           or else Name = "ada"
           or else Name = "markdown";
      end Is_Bundled_Icon;

      procedure Add_Icon
        (Item : Item_Snapshot;
         X    : Natural;
         Y    : Natural;
         Size : Natural)
      is
         Base_Color : constant Render_Color := Icon_Color (Item.Kind);
         Type_Name  : constant String := To_String (Item.Filetype);
         Icon_Name  : constant String := To_String (Item.Icon_Id);
         Draw_Size  : constant Natural :=
           Natural'Min
             (Size,
              Natural'Min
                (Clipped_Size (X, Size, Layout.Width),
                 Clipped_Size (Y, Size, Layout.Height)));
         Accent     : constant Render_Color :=
           (if Item.Kind = Files.Types.Executable_Item or else Icon_Name = "ada"
            then Icon_Executable_Color
            else Selection_Color);
         Fold       : constant Natural := Natural'Max (1, Draw_Size / 4);
         Stripe_W   : constant Natural := Natural'Max (1, Draw_Size / 5);
         Body_Y     : constant Natural := Saturating_Add (Y, Natural'Max (1, Draw_Size / 4));
         Body_H     : constant Natural :=
           (if Draw_Size > Body_Y - Y then Draw_Size - (Body_Y - Y) else Draw_Size);

         function Scale (Numerator : Natural; Denominator : Positive) return Natural is
         begin
            return Bounded_Product_Divide (Draw_Size, Numerator, Denominator);
         end Scale;

         function X_Offset (Offset : Natural) return Natural is
         begin
            return Saturating_Add (X, Offset);
         end X_Offset;

         function Y_Offset (Offset : Natural) return Natural is
         begin
            return Saturating_Add (Y, Offset);
         end Y_Offset;

         function Asset_Color (Role : Icon_Asset_Color_Role) return Render_Color is
         begin
            case Role is
               when Icon_Asset_Base =>
                  return Base_Color;
               when Icon_Asset_Accent =>
                  return Accent;
               when Icon_Asset_Border =>
                  return Border_Color;
               when Icon_Asset_Muted =>
                  return Muted_Text_Color;
            end case;
         end Asset_Color;

         procedure Add_Asset_Rect
         (Asset : Icon_Asset;
          Rect  : Icon_Asset_Rect)
         is
            Rect_X : constant Natural :=
              Saturating_Add
                (X, Bounded_Product_Divide (Value => Rect.Grid_X, Factor => Draw_Size, Denominator => Asset.Grid));
            Rect_Y : constant Natural :=
              Saturating_Add
                (Y, Bounded_Product_Divide (Value => Rect.Grid_Y, Factor => Draw_Size, Denominator => Asset.Grid));
            Rect_W : constant Natural :=
              Natural'Max
                (1, Bounded_Product_Divide (Value => Rect.Grid_W, Factor => Draw_Size, Denominator => Asset.Grid));
            Rect_H : constant Natural :=
              Natural'Max
                (1, Bounded_Product_Divide (Value => Rect.Grid_H, Factor => Draw_Size, Denominator => Asset.Grid));
         begin
            Add_Rect (Rect_X, Rect_Y, Rect_W, Rect_H, Asset_Color (Rect.Role));
         end Add_Asset_Rect;

         function Add_Named_Asset (Name : String) return Boolean is
            Asset : constant Icon_Asset := Parse_Icon_Asset (Icon_Asset_Text (Name, Icon_Theme_Name));
         begin
            if not Asset.Valid then
               return False;
            end if;

            for Rect of Asset.Rectangles loop
               Add_Asset_Rect (Asset, Rect);
            end loop;
            Add_Border (X, Y, Draw_Size, Draw_Size, Border_Color);
            return True;
         end Add_Named_Asset;

         function Starts_With
           (Value  : String;
            Prefix : String)
            return Boolean
         is
         begin
            return Value'Length >= Prefix'Length
              and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
         end Starts_With;

         function Resolved_Icon_Name return String is
         begin
            if Is_Bundled_Icon (Icon_Name) then
               return Icon_Name;
            elsif Item.Kind = Files.Types.Directory_Item then
               return "folder";
            elsif Item.Kind = Files.Types.Executable_Item then
               return "executable";
            elsif Item.Kind = Files.Types.Symlink_Item then
               return "link";
            elsif Icon_Name = "image" or else Starts_With (Type_Name, "image/") then
               return "image";
            elsif Type_Name = "text/markdown" then
               return "markdown";
            elsif Type_Name = "application/octet-stream" then
               return "unknown";
            elsif Starts_With (Type_Name, "text/") then
               return "text";
            else
               return "unknown";
            end if;
         end Resolved_Icon_Name;

         Resolved_Name : constant String := Resolved_Icon_Name;
      begin
         if Draw_Size = 0 then
            return;
         end if;

         Result.Icons.Append
           (Icon_Command'
              (X          => X,
               Y          => Y,
               Size       => Draw_Size,
               Icon_Id    => To_Unbounded_String (Resolved_Name),
               Theme_Name => To_Unbounded_String (Icon_Theme_Name),
               Asset_Path =>
                 To_Unbounded_String (Icon_Asset_Directory & "/" & Resolved_Name & ".icon")));

         if Add_Named_Asset (Icon_Name) then
            return;
         elsif Item.Kind = Files.Types.Directory_Item and then Add_Named_Asset ("folder") then
            return;
         elsif Item.Kind = Files.Types.Executable_Item and then Add_Named_Asset ("executable") then
            return;
         elsif Item.Kind = Files.Types.Symlink_Item and then Add_Named_Asset ("link") then
            return;
         elsif Icon_Name = "image" or else Starts_With (Type_Name, "image/") then
            if Add_Named_Asset ("image") then
               return;
            end if;
         elsif Type_Name = "text/markdown" then
            if Add_Named_Asset ("markdown") then
               return;
            end if;
         elsif Type_Name = "application/octet-stream" then
            if Add_Named_Asset ("unknown") then
               return;
            end if;
         elsif Starts_With (Type_Name, "text/") then
            if Add_Named_Asset ("text") then
               return;
            end if;
         end if;

         case Item.Kind is
            when Files.Types.Directory_Item =>
               Add_Rect
                 (X,
                  Y_Offset (Scale (1, 6)),
                  Natural'Max (1, Scale (1, 2)),
                  Natural'Max (1, Scale (1, 5)),
                  Base_Color);
               Add_Rect (X, Body_Y, Draw_Size, Body_H, Base_Color);
               if Draw_Size > 4 then
                  Add_Rect (X_Offset (1), Saturating_Add (Body_Y, 1), Draw_Size - 2, 1, Border_Color);
               end if;

            when Files.Types.Executable_Item =>
               Add_Rect (X, Y, Draw_Size, Draw_Size, Icon_File_Color);
               Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
               Add_Rect (X, Y, Stripe_W, Draw_Size, Accent);
               if Draw_Size > 6 then
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (1, 3)),
                     Stripe_W,
                     Scale (1, 3),
                     Accent);
                  Add_Rect
                    (X_Offset (Saturating_Add (Scale (1, 2), Stripe_W)),
                     Y_Offset (Scale (1, 2)),
                     Stripe_W,
                     Stripe_W,
                     Accent);
               end if;

            when Files.Types.Symlink_Item =>
               Add_Rect (X, Y, Draw_Size, Draw_Size, Icon_File_Color);
               Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
               if Draw_Size > 5 then
                  Add_Rect
                    (X_Offset (Scale (1, 5)),
                     Y_Offset (Scale (1, 2)),
                     Scale (1, 2),
                     Natural'Max (1, Scale (1, 6)),
                     Selection_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (1, 3)),
                     Scale (1, 4),
                     Natural'Max (1, Scale (1, 6)),
                     Selection_Color);
                  Add_Rect
                    (X_Offset (Scale (1, 2)),
                     Y_Offset (Scale (2, 3)),
                     Scale (1, 4),
                     Natural'Max (1, Scale (1, 6)),
                     Selection_Color);
               end if;

            when Files.Types.Regular_File_Item | Files.Types.Other_Item =>
               Add_Rect (X, Y, Draw_Size, Draw_Size, Base_Color);
               Add_Rect (X_Offset (Draw_Size - Fold), Y, Fold, Fold, Muted_Text_Color);
               if Draw_Size > 7 then
                  if Icon_Name = "image"
                    or else Starts_With (Type_Name, "image/")
                  then
                     Add_Rect
                       (X_Offset (Scale (1, 5)),
                        Y_Offset (Scale (1, 3)),
                        Scale (3, 5),
                        Scale (1, 3),
                        Selection_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 4)),
                        Y_Offset (Scale (1, 2)),
                        Scale (1, 5),
                        Scale (1, 6),
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 2)),
                        Y_Offset (Scale (1, 2)),
                        Scale (1, 4),
                        Scale (1, 6),
                        Border_Color);
                  elsif Icon_Name = "ada" or else Type_Name = "text/x-ada" then
                     Add_Rect
                       (X_Offset (Scale (1, 5)),
                        Y_Offset (Scale (1, 3)),
                        Scale (1, 5),
                        Scale (1, 2),
                        Icon_Executable_Color);
                     Add_Rect
                       (X_Offset (Scale (3, 5)),
                        Y_Offset (Scale (1, 3)),
                        Scale (1, 5),
                        Scale (1, 2),
                        Icon_Executable_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 4)),
                        Y_Offset (Scale (1, 2)),
                        Scale (1, 2),
                        Natural'Max (1, Scale (1, 6)),
                        Selection_Color);
                  elsif Icon_Name = "markdown" or else Type_Name = "text/markdown" then
                     Add_Rect
                       (X_Offset (Scale (1, 5)),
                        Y_Offset (Scale (1, 3)),
                        Scale (1, 5),
                        Scale (1, 2),
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (2, 5)),
                        Y_Offset (Scale (1, 2)),
                        Scale (1, 5),
                        Scale (1, 3),
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (3, 5)),
                        Y_Offset (Scale (1, 3)),
                        Scale (1, 5),
                        Scale (1, 2),
                        Border_Color);
                  elsif Icon_Name = "unknown" or else Type_Name = "application/octet-stream" then
                     Add_Rect
                       (X_Offset (Scale (1, 3)),
                        Y_Offset (Scale (1, 4)),
                        Scale (1, 3),
                        Natural'Max (1, Scale (1, 6)),
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 2)),
                        Y_Offset (Scale (1, 3)),
                        Natural'Max (1, Scale (1, 6)),
                        Scale (1, 3),
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 2)),
                        Y_Offset (Scale (3, 4)),
                        Natural'Max (1, Scale (1, 6)),
                        1,
                        Border_Color);
                  else
                     Add_Rect (X_Offset (Scale (1, 5)), Y_Offset (Scale (1, 2)), Scale (3, 5), 1, Border_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 5)),
                        Y_Offset (Saturating_Add (Scale (1, 2), Scale (1, 5))),
                        Scale (1, 2),
                        1,
                        Border_Color);
                     Add_Rect
                       (X_Offset (Scale (1, 5)),
                        Y_Offset (Scale (1, 2) - Scale (1, 5)),
                        Scale (1, 2),
                        1,
                        Border_Color);
                  end if;
               end if;

            when Files.Types.Unknown_Item =>
               Add_Rect (X_Offset (Scale (1, 4)), Y, Scale (1, 2), Draw_Size, Base_Color);
               Add_Rect (X, Y_Offset (Scale (1, 4)), Draw_Size, Scale (1, 2), Base_Color);
               if Draw_Size > 5 then
                  Add_Rect (X_Offset (Scale (1, 2)), Y_Offset (Scale (1, 4)), 1, Scale (1, 2), Border_Color);
               end if;
         end case;
      end Add_Icon;

      procedure Add_Button
        (X        : Natural;
         Button_W : Natural;
         Selected : Boolean;
         Hovered  : Boolean := False;
         Pressed  : Boolean := False) is
      begin
         Add_Rect
           (X,
            Bottom_Y,
            Button_W,
            Layout.Bottom_Bar_Height,
            (if Selected then Selection_Color
             elsif Pressed then Pressed_Color
             elsif Hovered then Hover_Color
             else Bottom_Bar_Color));
         if Selected then
            Add_Border (X, Bottom_Y, Button_W, Layout.Bottom_Bar_Height, Border_Color);
         end if;
      end Add_Button;

      function Command_Label (Id : Files.Commands.Command_Id) return UString is
      begin
         return To_Unbounded_String (Files.Localization.Text (Files.Commands.Name_Key (Id)));
      end Command_Label;

      function Command_Color (Id : Files.Commands.Registered_Command_Id) return Render_Color is
      begin
         return (if Snapshot.Command_Enabled (Id) then Text_Color else Disabled_Text_Color);
      end Command_Color;

      procedure Add_Bottom_Command_Button
        (X        : Natural;
         Button_W : Natural;
         Command  : Files.Commands.Registered_Command_Id;
         Selected : Boolean)
      is
         Hovered : constant Boolean :=
           Has_Hover and then Contains_Point (X, Bottom_Y, Button_W, Layout.Bottom_Bar_Height, Hover_X, Hover_Y);
         Pressed : constant Boolean := Is_Pressed (X, Bottom_Y, Button_W, Layout.Bottom_Bar_Height);
      begin
         Add_Button (X, Button_W, Selected, Hovered, Pressed);
         Add_Text
           (Saturating_Add (X, 4),
            Bottom_Y,
            (if Button_W > 8 then Button_W - 8 else 0),
            Layout.Bottom_Bar_Height,
            Command_Label (Command),
            Command_Color (Command),
            Fit => True);
         Add_Tooltip
           (X,
            Bottom_Y,
            Button_W,
            Layout.Bottom_Bar_Height,
            Files.Commands.Description_Key (Command));
         Add_Accessibility_Node
           (Role_Button,
            X,
            Bottom_Y,
            Button_W,
            Layout.Bottom_Bar_Height,
            Command_Label (Command),
            Localized (Files.Commands.Description_Key (Command)),
            Enabled  => Snapshot.Command_Enabled (Command),
            Selected => Selected);
      end Add_Bottom_Command_Button;

      function Natural_Text (Value : Natural) return String is
         Image : constant String := Natural'Image (Value);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Natural_Text;

      function View_Mode_Label return String is
      begin
         case Snapshot.View_Mode is
            when Files.Types.Small_Icons =>
               return Files.Localization.Text ("command.view.small");
            when Files.Types.Large_Icons =>
               return Files.Localization.Text ("command.view.large");
            when Files.Types.Details =>
               return Files.Localization.Text ("command.view.details");
         end case;
      end View_Mode_Label;

      function Count_Status_Text return UString is
      begin
         return
           To_Unbounded_String
             (Files.Localization.Text ("status.items")
              & ": "
              & Natural_Text (Snapshot.Item_Count)
              & "  "
              & Files.Localization.Text ("status.visible")
              & ": "
              & Natural_Text (Snapshot.Visible_Count)
              & "  "
              & Files.Localization.Text ("status.selected")
              & ": "
              & Natural_Text (Snapshot.Selected_Count));
      end Count_Status_Text;

      function Bottom_Info_Text return UString is
      begin
         if Length (Snapshot.Last_Error_Key) > 0 then
            return To_Unbounded_String (Files.Localization.Text (To_String (Snapshot.Last_Error_Key)));
         end if;

         return Count_Status_Text;
      end Bottom_Info_Text;

      function Main_View_Accessible_Description return UString is
      begin
         return
           To_Unbounded_String
             (Files.Localization.Text ("settings.default_view")
              & ": "
              & View_Mode_Label
              & "  ")
           & Count_Status_Text;
      end Main_View_Accessible_Description;

      function Bottom_Info_Color return Render_Color is
      begin
         return (if Length (Snapshot.Last_Error_Key) > 0 then Error_Text_Color else Muted_Text_Color);
      end Bottom_Info_Color;

      function Empty_State_Key return String is
      begin
         if Snapshot.Item_Count = 0 then
            return "status.empty_directory";
         elsif Snapshot.Visible_Count = 0 and then Length (Snapshot.Filter_Text) > 0 then
            return "status.empty_filter";
         else
            return "";
         end if;
      end Empty_State_Key;

      function Info_Value
        (Label_Key : String;
         Value     : String)
         return UString
      is
      begin
         return To_Unbounded_String (Files.Localization.Text (Label_Key) & ": " & Value);
      end Info_Value;

      function Missing_Info (Label_Key : String) return UString is
      begin
         return Info_Value (Label_Key, Files.Localization.Text ("status.missing_metadata"));
      end Missing_Info;

      function Integer_Text (Value : Long_Long_Integer) return String is
         Image : constant String := Long_Long_Integer'Image (Value);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Integer_Text;

      function Time_Text
        (Available : Boolean;
         Value     : Ada.Calendar.Time;
         Label_Key : String)
         return UString
      is
      begin
         if not Available then
            return Missing_Info (Label_Key);
         end if;

         return
           Info_Value
             (Label_Key,
              Ada.Calendar.Formatting.Image
                (Date                  => Value,
                 Include_Time_Fraction => False,
                 Time_Zone             => 0));
      end Time_Text;

      function Detail_Size_Text (Item : Item_Snapshot) return UString is
      begin
         if not Item.Size_Available then
            return To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"));
         end if;

         return To_Unbounded_String (Integer_Text (Item.Size));
      end Detail_Size_Text;

      function Detail_Time_Text (Item : Item_Snapshot) return UString is
      begin
         if not Item.Modified_Available then
            return To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"));
         end if;

         return
           To_Unbounded_String
             (Ada.Calendar.Formatting.Image
                (Date                  => Item.Modified_Time,
                 Include_Time_Fraction => False,
                 Time_Zone             => 0));
      end Detail_Time_Text;

      function Permission_Text (Permissions : String) return String is
         Result : Unbounded_String;

         procedure Append_Part (Key : String) is
         begin
            if Length (Result) > 0 then
               Append (Result, Files.Localization.Text ("info.permissions.separator"));
            end if;
            Append (Result, Files.Localization.Text (Key));
         end Append_Part;
      begin
         if Permissions'Length < 3 then
            return Permissions;
         end if;

         if Permissions (Permissions'First) = 'r' then
            Append_Part ("info.permissions.readable");
         end if;
         if Permissions (Permissions'First + 1) = 'w' then
            Append_Part ("info.permissions.writable");
         end if;
         if Permissions (Permissions'First + 2) = 'x' then
            Append_Part ("info.permissions.executable");
         end if;
         if Length (Result) = 0 then
            return Files.Localization.Text ("info.permissions.none");
         end if;

         return To_String (Result) & " (" & Permissions & ")";
      end Permission_Text;
   begin
      Result.Layout := Layout;

      Add_Rect (0, 0, Width, Height, Canvas_Color);
      Add_Rect (0, 0, Width, Layout.Toolbar_Height, Toolbar_Color);
      Add_Rect (Layout.Main_X, Layout.Main_Y, Layout.Main_Width, Layout.Main_Height, Main_Color);
      Add_Rect (0, Bottom_Y, Width, Layout.Bottom_Bar_Height, Bottom_Bar_Color);
      if Layout.Toolbar_Height > 0 then
         Add_Rect (0, Layout.Toolbar_Height - 1, Width, 1, Border_Color);
      end if;
      Add_Rect (0, Bottom_Y, Width, 1, Border_Color);
      Add_Accessibility_Node
        (Role_Window,
         0,
         0,
         Width,
         Height,
         Snapshot.Current_Path);
      Add_Accessibility_Node
        (Role_Toolbar,
         0,
         0,
         Width,
         Layout.Toolbar_Height,
         Localized ("accessibility.toolbar"));
      Add_Accessibility_Node
        ((if Snapshot.View_Mode = Files.Types.Details then Role_Table else Role_List),
         Layout.Main_X,
         Layout.Main_Y,
         Layout.Main_Width,
         Layout.Main_Height,
         Localized ("accessibility.main_view"),
         Main_View_Accessible_Description);

      if Layout.Info_Pane_Width > 0 then
         Add_Rect
           (Layout.Main_Width,
            Layout.Main_Y,
            Layout.Info_Pane_Width,
            Layout.Main_Height,
            Pane_Color);
         Add_Rect
           (Layout.Main_Width,
            Layout.Main_Y,
            1,
            Layout.Main_Height,
            Border_Color);
      end if;

      for Button_Index in 0 .. 5 loop
         declare
            Button_X : constant Natural := Files.UI.Toolbar_Left_Button_X (Toolbar, Button_Index);
            Button_W : constant Natural := Files.UI.Toolbar_Left_Button_Width (Toolbar, Button_Index);
            Command  : constant Files.Commands.Registered_Command_Id :=
              (case Button_Index is
                  when 0 => Files.Commands.Select_Drive_Command,
                  when 1 => Files.Commands.Navigate_Home_Command,
                  when 2 => Files.Commands.Navigate_Back_Command,
                  when 3 => Files.Commands.Navigate_Forward_Command,
                  when 4 => Files.Commands.Create_File_Command,
                  when others => Files.Commands.Delete_Selected_Items_Command);
            Icon_Size : constant Natural :=
              (if Line_Height > 6 then Line_Height - 6 else 0);
            Icon_X   : constant Natural :=
              (if Button_W > Icon_Size then Button_X + (Button_W - Icon_Size) / 2 else Button_X);
            Icon_Y   : constant Natural :=
              (if Line_Height > Icon_Size then (Line_Height - Icon_Size) / 2 else 0);
            Text_X   : constant Natural := Button_X + 2;
            Text_W   : constant Natural :=
              (if Button_W > 4 then Button_W - 4 else 0);
            Text_Y   : constant Natural :=
              (if Layout.Toolbar_Height > Line_Height then Line_Height else 0);
            Enabled  : constant Boolean := Snapshot.Command_Enabled (Command);
            Hovered  : constant Boolean :=
              Has_Hover and then Contains_Point (Button_X, 0, Button_W, Layout.Toolbar_Height, Hover_X, Hover_Y);
            Pressed  : constant Boolean := Is_Pressed (Button_X, 0, Button_W, Layout.Toolbar_Height);
         begin
            Add_Rect
              (Button_X,
               0,
               Button_W,
               Layout.Toolbar_Height,
               (if not Enabled then Pane_Color
                elsif Pressed then Pressed_Color
                elsif Hovered then Hover_Color
                else Toolbar_Color));
            if not Enabled then
               Add_Border
                 (Button_X, 0, Button_W, Layout.Toolbar_Height, Border_Color);
            end if;
            Add_Toolbar_Glyph (Command, Icon_X, Icon_Y, Natural'Min (Icon_Size, Button_W), Enabled);
            Add_Text
              (Text_X,
               Text_Y,
               Text_W,
               Natural'Min (Line_Height, Layout.Toolbar_Height),
               Command_Label (Command),
               Command_Color (Command),
               Fit => True);
            Add_Tooltip
              (Button_X,
               0,
               Button_W,
               Layout.Toolbar_Height,
               Files.Commands.Description_Key (Command));
            Add_Accessibility_Node
              (Role_Button,
               Button_X,
               0,
               Button_W,
               Layout.Toolbar_Height,
               Command_Label (Command),
               Localized (Files.Commands.Description_Key (Command)),
               Enabled => Enabled);
         end;
      end loop;

      Add_Rect
        (Toolbar.Middle_X,
         Line_Height / 2,
         Toolbar.Middle_Width,
         Line_Height,
         (if Snapshot.Path_Input_Valid then Input_Color else Input_Error_Color));
      Add_Text
        (Toolbar.Middle_X + 4,
         Line_Height / 2,
         (if Toolbar.Middle_Width > 8 then Toolbar.Middle_Width - 8 else 0),
         Line_Height,
         Snapshot.Path_Input_Text,
         Fit => True);
      if Snapshot.Focus = Files.Types.Focus_Path_Input or else not Snapshot.Path_Input_Valid then
         Add_Border
           (Toolbar.Middle_X,
            Line_Height / 2,
            Toolbar.Middle_Width,
            Line_Height,
            (if Snapshot.Path_Input_Valid then Border_Color else Input_Error_Color));
      elsif Has_Hover
        and then Contains_Point
          (Toolbar.Middle_X, Line_Height / 2, Toolbar.Middle_Width, Line_Height, Hover_X, Hover_Y)
      then
         Add_Border (Toolbar.Middle_X, Line_Height / 2, Toolbar.Middle_Width, Line_Height, Hover_Color);
      end if;
      if Is_Pressed (Toolbar.Middle_X, Line_Height / 2, Toolbar.Middle_Width, Line_Height) then
         Add_Border (Toolbar.Middle_X, Line_Height / 2, Toolbar.Middle_Width, Line_Height, Pressed_Color);
      end if;
      if Snapshot.Focus = Files.Types.Focus_Path_Input then
         Add_Focus_Ring (Toolbar.Middle_X, Line_Height / 2, Toolbar.Middle_Width, Line_Height);
         Add_Caret (Toolbar.Middle_X, Line_Height / 2, Toolbar.Middle_Width, Line_Height);
      end if;
      Add_Tooltip
        (Toolbar.Middle_X,
         Line_Height / 2,
         Toolbar.Middle_Width,
         Line_Height,
         Files.Commands.Description_Key (Files.Commands.Focus_Path_Input_Command));
      Add_Accessibility_Node
        (Role_Text_Input,
         Toolbar.Middle_X,
         Line_Height / 2,
         Toolbar.Middle_Width,
         Line_Height,
         Localized (Files.Commands.Name_Key (Files.Commands.Focus_Path_Input_Command)),
         Path_Input_Accessible_Description,
         Enabled => True,
         Focused => Snapshot.Focus = Files.Types.Focus_Path_Input);
      Add_Rect
        (Toolbar.Right_X,
         Line_Height / 2,
         Toolbar.Right_Width,
         Line_Height,
         Input_Color);
      Add_Text
        (Toolbar.Right_X + 4,
         Line_Height / 2,
         (if Toolbar.Right_Width > 8 then Toolbar.Right_Width - 8 else 0),
         Line_Height,
         Snapshot.Filter_Text,
         Fit => True);
      if Snapshot.Focus = Files.Types.Focus_Filter_Input then
         Add_Border (Toolbar.Right_X, Line_Height / 2, Toolbar.Right_Width, Line_Height, Border_Color);
         Add_Focus_Ring (Toolbar.Right_X, Line_Height / 2, Toolbar.Right_Width, Line_Height);
         Add_Caret (Toolbar.Right_X, Line_Height / 2, Toolbar.Right_Width, Line_Height);
      elsif Has_Hover
        and then Contains_Point
          (Toolbar.Right_X, Line_Height / 2, Toolbar.Right_Width, Line_Height, Hover_X, Hover_Y)
      then
         Add_Border (Toolbar.Right_X, Line_Height / 2, Toolbar.Right_Width, Line_Height, Hover_Color);
      end if;
      if Is_Pressed (Toolbar.Right_X, Line_Height / 2, Toolbar.Right_Width, Line_Height) then
         Add_Border (Toolbar.Right_X, Line_Height / 2, Toolbar.Right_Width, Line_Height, Pressed_Color);
      end if;
      Add_Tooltip
        (Toolbar.Right_X,
         Line_Height / 2,
         Toolbar.Right_Width,
         Line_Height,
         Files.Commands.Description_Key (Files.Commands.Focus_Filter_Input_Command));
      Add_Accessibility_Node
        (Role_Text_Input,
         Toolbar.Right_X,
         Line_Height / 2,
         Toolbar.Right_Width,
         Line_Height,
         Localized (Files.Commands.Name_Key (Files.Commands.Focus_Filter_Input_Command)),
         Snapshot.Filter_Text,
         Enabled => True,
         Focused => Snapshot.Focus = Files.Types.Focus_Filter_Input);
      if Layout.Toolbar_Height > 0 and then Toolbar.Middle_X > 0 then
         Add_Rect (Toolbar.Middle_X, 0, 1, Layout.Toolbar_Height, Border_Color);
      end if;
      if Layout.Toolbar_Height > 0 and then Toolbar.Right_X > 0 then
         Add_Rect (Toolbar.Right_X, 0, 1, Layout.Toolbar_Height, Border_Color);
      end if;

      Add_Bottom_Command_Button
        (Bottom.Small_Button_X,
         Bottom.Small_Button_Width,
         Files.Commands.Select_Small_Icons_Command,
         Snapshot.View_Mode = Files.Types.Small_Icons);
      Add_Bottom_Command_Button
        (Bottom.Large_Button_X,
         Bottom.Large_Button_Width,
         Files.Commands.Select_Large_Icons_Command,
         Snapshot.View_Mode = Files.Types.Large_Icons);
      Add_Bottom_Command_Button
        (Bottom.Details_Button_X,
         Bottom.Details_Button_Width,
         Files.Commands.Select_Details_Command,
         Snapshot.View_Mode = Files.Types.Details);
      Add_Rect
        (Bottom.Info_X,
         Bottom_Y,
         Bottom.Info_Width,
         Layout.Bottom_Bar_Height,
         Bottom_Bar_Color);
      Add_Text
        (Saturating_Add (Bottom.Info_X, 4),
         Bottom_Y,
         (if Bottom.Info_Width > 8 then Bottom.Info_Width - 8 else 0),
         Layout.Bottom_Bar_Height,
         Bottom_Info_Text,
         Bottom_Info_Color,
         Fit => True);
      Add_Accessibility_Node
        (Role_Status,
         Bottom.Info_X,
         Bottom_Y,
         Bottom.Info_Width,
         Layout.Bottom_Bar_Height,
         Bottom_Info_Text);
      Add_Rect
        (Bottom.Info_Pane_X,
         Bottom_Y,
         Bottom.Info_Pane_Width,
         Layout.Bottom_Bar_Height,
         (if Snapshot.Info_Pane_Open
          then Selection_Color
          elsif Is_Pressed
            (Bottom.Info_Pane_X,
             Bottom_Y,
             Bottom.Info_Pane_Width,
             Layout.Bottom_Bar_Height)
          then Pressed_Color
          elsif Has_Hover
            and then Contains_Point
              (Bottom.Info_Pane_X,
               Bottom_Y,
               Bottom.Info_Pane_Width,
               Layout.Bottom_Bar_Height,
               Hover_X,
               Hover_Y)
          then Hover_Color
          else Bottom_Bar_Color));
      Add_Text
        (Saturating_Add (Bottom.Info_Pane_X, 4),
         Bottom_Y,
         (if Bottom.Info_Pane_Width > 8 then Bottom.Info_Pane_Width - 8 else 0),
         Layout.Bottom_Bar_Height,
         Command_Label (Files.Commands.Toggle_Info_Pane_Command),
         Command_Color (Files.Commands.Toggle_Info_Pane_Command),
         Fit => True);
      Add_Tooltip
        (Bottom.Info_Pane_X,
         Bottom_Y,
         Bottom.Info_Pane_Width,
         Layout.Bottom_Bar_Height,
         Files.Commands.Description_Key (Files.Commands.Toggle_Info_Pane_Command));
      Add_Accessibility_Node
        (Role_Button,
         Bottom.Info_Pane_X,
         Bottom_Y,
         Bottom.Info_Pane_Width,
         Layout.Bottom_Bar_Height,
         Command_Label (Files.Commands.Toggle_Info_Pane_Command),
         Localized (Files.Commands.Description_Key (Files.Commands.Toggle_Info_Pane_Command)),
         Enabled  => Snapshot.Command_Enabled (Files.Commands.Toggle_Info_Pane_Command),
         Selected => Snapshot.Info_Pane_Open);
      if Layout.Bottom_Bar_Height > 0 and then Bottom.Info_X > 0 then
         Add_Rect (Bottom.Info_X, Bottom_Y, 1, Layout.Bottom_Bar_Height, Border_Color);
      end if;
      if Layout.Bottom_Bar_Height > 0 and then Bottom.Info_Pane_X > 0 then
         Add_Rect (Bottom.Info_Pane_X, Bottom_Y, 1, Layout.Bottom_Bar_Height, Border_Color);
      end if;

      if Snapshot.View_Mode = Files.Types.Details then
         declare
            Header_H  : constant Natural := Natural'Min (Line_Height, Layout.Main_Height);
            Header_Y  : constant Natural := Layout.Main_Y;
            Header_W  : constant Natural := Layout.Main_Width;
            Text_Y    : constant Natural := Header_Y;
            Icon_Gap  : constant Natural := Saturating_Add (Line_Height, 4);
            Content_X : constant Natural := Saturating_Add (Layout.Main_X, Icon_Gap);
            Available : constant Natural :=
              (if Layout.Main_Width > Icon_Gap then Layout.Main_Width - Icon_Gap else 0);
            Type_W    : constant Natural := Natural'Min (160, Available / 4);
            Size_W    : constant Natural := Natural'Min (96, Available / 6);
            Modified_W : constant Natural := Natural'Min (180, Available / 4);
            Name_X    : constant Natural := Content_X;
            Name_W    : constant Natural :=
              (if Available > Saturating_Add (Saturating_Add (Type_W, Size_W), Modified_W)
               then Available - Type_W - Size_W - Modified_W
               else 0);
            Modified_X : constant Natural := Saturating_Add (Name_X, Name_W);
            Size_X    : constant Natural := Saturating_Add (Modified_X, Modified_W);
            Type_X    : constant Natural := Saturating_Add (Size_X, Size_W);
         begin
            Add_Rect (Layout.Main_X, Header_Y, Header_W, Header_H, Pane_Color);
            Add_Border (Layout.Main_X, Header_Y, Header_W, Header_H, Border_Color);
            Add_Text
              (Name_X,
               Text_Y,
               Name_W,
               Header_H,
               To_Unbounded_String (Files.Localization.Text ("details.name")),
               Muted_Text_Color,
               Fit => True);
            Add_Text
              (Modified_X,
               Text_Y,
               Modified_W,
               Header_H,
               To_Unbounded_String (Files.Localization.Text ("details.modified")),
               Muted_Text_Color,
               Fit => True);
            Add_Text
              (Size_X,
               Text_Y,
               Size_W,
               Header_H,
               To_Unbounded_String (Files.Localization.Text ("details.size")),
               Muted_Text_Color,
               Fit => True);
            Add_Text
              (Type_X,
               Text_Y,
               Type_W,
               Header_H,
               To_Unbounded_String (Files.Localization.Text ("details.filetype")),
               Muted_Text_Color,
               Fit => True);
            Add_Accessibility_Node
              (Role_Table_Row,
               Layout.Main_X,
               Header_Y,
               Header_W,
               Header_H,
               To_Unbounded_String (Files.Localization.Text ("details.header")),
               To_Unbounded_String
                 (Files.Localization.Text ("details.name") & ", " &
                  Files.Localization.Text ("details.modified") & ", " &
                  Files.Localization.Text ("details.size") & ", " &
                  Files.Localization.Text ("details.filetype")));

            if Header_H > 0 then
               Add_Rect ((if Modified_X > 2 then Modified_X - 2 else 0), Header_Y, 1, Layout.Main_Height, Border_Color);
               Add_Rect ((if Size_X > 2 then Size_X - 2 else 0), Header_Y, 1, Layout.Main_Height, Border_Color);
               Add_Rect ((if Type_X > 2 then Type_X - 2 else 0), Header_Y, 1, Layout.Main_Height, Border_Color);
               Add_Rect
                 (Layout.Main_X,
                  Saturating_Add (Header_Y, Header_H - Natural'Min (2, Header_H)),
                  Header_W,
                  Natural'Min (2, Header_H),
                  Selection_Color);
            end if;
         end;
      end if;

      for Index in 1 .. Natural (Items.Length) loop
         declare
            Item      : constant Item_Snapshot := Snapshot.Items.Element (Positive (Index));
            Item_Rect : constant Item_Layout := Items.Element (Positive (Index));
            Hovered   : constant Boolean :=
              Has_Hover
              and then Contains_Point
                (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Hover_X, Hover_Y);
            Pressed   : constant Boolean :=
              Is_Pressed (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height);
         begin
            if Item.Selected then
               Add_Rect (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Selection_Color);
               Add_Border (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Selection_Color);
               Add_Rect
                 (Item_Rect.X,
                  Item_Rect.Y,
                  Natural'Min (3, Item_Rect.Width),
                  Item_Rect.Height,
                  Border_Color);
            elsif Pressed then
               Add_Rect (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Pressed_Color);
               Add_Border (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Pressed_Color);
            elsif Hovered then
               Add_Rect (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Hover_Color);
               Add_Border (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Hover_Color);
            elsif Snapshot.View_Mode = Files.Types.Details and then Index mod 2 = 0 then
               Add_Rect (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Detail_Alternate_Color);
            end if;

            Add_Icon (Item, Item_Rect.Icon_X, Item_Rect.Icon_Y, Item_Rect.Icon_Size);
            Add_Text
              (Item_Rect.Text_X,
               Item_Rect.Text_Y,
               Item_Rect.Text_Width,
               Item_Rect.Height,
               (if Snapshot.Rename_Active and then Item.Selected then Snapshot.Rename_Text else Item.Name),
               Fit => True);

            if Snapshot.Rename_Active
              and then Item.Selected
              and then Snapshot.Focus = Files.Types.Focus_Rename_Input
            then
               Add_Border (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Border_Color);
               Add_Focus_Ring (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height);
               declare
                  Caret_X     : constant Natural := (if Item_Rect.Text_X > 4 then Item_Rect.Text_X - 4 else 0);
                  Caret_Inset : constant Natural := Item_Rect.Text_X - Caret_X;
               begin
                  Add_Caret
                    (Caret_X,
                     Item_Rect.Text_Y,
                     Saturating_Add (Item_Rect.Text_Width, Caret_Inset),
                     Item_Rect.Height);
               end;
            end if;

            if Snapshot.View_Mode = Files.Types.Details then
               if Item_Rect.Height > 0 then
                  Add_Rect
                    (Item_Rect.X,
                     Item_Rect.Y + Item_Rect.Height - 1,
                     Item_Rect.Width,
                     1,
                     Border_Color);
               end if;
               Add_Text
                 (Item_Rect.Modified_X,
                  Item_Rect.Y,
                  Item_Rect.Modified_Width,
                  Item_Rect.Height,
                  Detail_Time_Text (Item),
                  Muted_Text_Color,
                  Fit => True);
               Add_Text
                 (Item_Rect.Size_X,
                  Item_Rect.Y,
                  Item_Rect.Size_Width,
                  Item_Rect.Height,
                  Detail_Size_Text (Item),
                  Muted_Text_Color,
                  Fit => True);
               Add_Text
                 (Item_Rect.Filetype_X,
                  Item_Rect.Y,
                  Item_Rect.Filetype_Width,
                  Item_Rect.Height,
                  Item.Filetype_Detail,
                  Muted_Text_Color,
                  Fit => True);
            end if;

            declare
               Row_Description : constant UString :=
                 (if Snapshot.View_Mode = Files.Types.Details
                  then To_Unbounded_String
                    (Files.Localization.Text ("details.modified") & ": " &
                     To_String (Detail_Time_Text (Item)) & ", " &
                     Files.Localization.Text ("details.size") & ": " &
                     To_String (Detail_Size_Text (Item)) & ", " &
                     Files.Localization.Text ("details.filetype") & ": " &
                     To_String (Item.Filetype_Detail))
                  else Item.Filetype_Detail);
            begin
               Add_Accessibility_Node
                 ((if Snapshot.View_Mode = Files.Types.Details then Role_Table_Row else Role_List_Item),
                  Item_Rect.X,
                  Item_Rect.Y,
                  Item_Rect.Width,
                  Item_Rect.Height,
                  Item.Name,
                  Row_Description,
                  Enabled  => True,
                  Selected => Item.Selected,
                  Focused  => Item.Selected);
            end;
         end;
      end loop;

      if Empty_State_Key /= "" and then Layout.Main_Width > 0 and then Layout.Main_Height > 0 then
         declare
            Text_H : constant Natural := Line_Height;
            Panel_W : constant Natural :=
              Natural'Min (Natural'Max (240, Layout.Main_Width / 2), Layout.Main_Width);
            Panel_H : constant Natural := Natural'Min (Saturating_Multiply (Line_Height, 3), Layout.Main_Height);
            Panel_X : constant Natural :=
              Saturating_Add
                (Layout.Main_X,
                 (if Layout.Main_Width > Panel_W then (Layout.Main_Width - Panel_W) / 2 else 0));
            Panel_Y : constant Natural :=
              Saturating_Add
                (Layout.Main_Y,
                 (if Layout.Main_Height > Panel_H then (Layout.Main_Height - Panel_H) / 2 else 0));
            Text_Y : constant Natural :=
              Saturating_Add (Panel_Y, (if Panel_H > Text_H then (Panel_H - Text_H) / 2 else 0));
            Icon_Size : constant Natural := Natural'Min (Line_Height, Panel_H);
            Icon_X : constant Natural := Saturating_Add (Panel_X, 8);
            Text_X : constant Natural := Saturating_Add (Panel_X, Saturating_Add (Icon_Size, 16));
            Text_W : constant Natural :=
              (if Panel_W > Saturating_Add (Icon_Size, 24)
               then Panel_W - Saturating_Add (Icon_Size, 24)
               else Panel_W);
         begin
            Add_Rect (Panel_X, Panel_Y, Panel_W, Panel_H, Pane_Color);
            Add_Border (Panel_X, Panel_Y, Panel_W, Panel_H, Border_Color);
            Add_Rect
              (Icon_X,
               Text_Y,
               Icon_Size,
               Natural'Min (Icon_Size, Text_H),
               Muted_Text_Color);
            if Icon_Size > 6 then
               Add_Rect
                 (Saturating_Add (Icon_X, Icon_Size / 4),
                  Saturating_Add (Text_Y, Icon_Size / 2),
                  Icon_Size / 2,
                  1,
                  Pane_Color);
            end if;
            Add_Text
              (Text_X,
               Text_Y,
               Text_W,
               Text_H,
               To_Unbounded_String (Files.Localization.Text (Empty_State_Key)),
               Muted_Text_Color,
               Fit => True);
         end;
      end if;

      if Main_View.Scrollbar_Visible then
         Add_Scrollbar
           (Main_View.Scrollbar_X,
            Main_View.Scrollbar_Y,
            Main_View.Scrollbar_Width,
            Layout.Main_Height,
            Main_View.Scrollbar_Thumb_Y,
            Main_View.Scrollbar_Height);
      end if;

      if Snapshot.Info_Pane_Open then
         Add_Rect
           (Info_Pane.X,
            Info_Pane.Y,
            Info_Pane.Width,
            Natural'Min (2, Info_Pane.Height),
            Border_Color);
         Add_Accessibility_Node
           (Role_Pane,
            Info_Pane.X,
            Info_Pane.Y,
            Info_Pane.Width,
            Info_Pane.Height,
            Localized ("accessibility.info_pane"));
         for Index in 1 .. Natural (Snapshot.Selected_Info.Length) loop
            declare
               Info   : constant Info_Snapshot := Snapshot.Selected_Info.Element (Positive (Index));
               Section_Offset : constant Natural :=
                 Saturating_Multiply
                   (Saturating_Multiply (Natural (Index - 1), Line_Height),
                    Info_Rows_Per_Item);
               Base_Y : constant Integer :=
                 Saturating_Integer_Add (Integer (Info_Pane.Y), Section_Offset);
               Row_Y  : constant Integer := Base_Y - Integer (Info_Pane.Scroll_Pixels);
               Text_X : constant Natural := Saturating_Add (Layout.Main_Width, 4);
               Info_Bottom : constant Natural := Saturating_Add (Info_Pane.Y, Info_Pane.Height);
               Text_W : constant Natural :=
                 (if Info_Pane.Scrollbar_Visible
                   and then Layout.Info_Pane_Width > Saturating_Add (Info_Pane.Scrollbar_Width, 8)
                  then Layout.Info_Pane_Width - Info_Pane.Scrollbar_Width - 8
                  elsif Layout.Info_Pane_Width > 8
                  then Layout.Info_Pane_Width - 8
                  else 0);

               procedure Add_Info_Text
                 (Offset : Natural;
                  Text   : UString;
                  Color  : Render_Color := Text_Color)
               is
                  Y : constant Integer :=
                    Saturating_Integer_Add (Row_Y, Saturating_Multiply (Offset, Line_Height));
               begin
                  if Y >= Integer (Info_Pane.Y)
                    and then Y < Integer (Info_Bottom)
                  then
                     Add_Text (Text_X, Natural (Y), Text_W, Line_Height, Text, Color, Fit => True);
                  end if;
               end Add_Info_Text;
            begin
               Add_Info_Text (0, Info_Value ("info.name", To_String (Info.Name)));
               Add_Info_Text (1, Info_Value ("info.filetype", To_String (Info.Filetype)), Muted_Text_Color);
               if Info.Size_Available then
                  Add_Info_Text
                    (2,
                     Info_Value ("info.size", Integer_Text (Info.Size)),
                     Muted_Text_Color);
               else
                  Add_Info_Text (2, Missing_Info ("info.size"), Muted_Text_Color);
               end if;
               Add_Info_Text
                 (3,
                  Time_Text (Info.Creation_Available, Info.Creation_Time, "info.created"),
                  Muted_Text_Color);
               Add_Info_Text
                 (4,
                  Time_Text (Info.Modified_Available, Info.Modified_Time, "info.modified"),
                  Muted_Text_Color);
               if Length (Info.Permissions) = 0 then
                  Add_Info_Text (5, Missing_Info ("info.permissions"), Muted_Text_Color);
               else
                  Add_Info_Text
                    (5,
                     Info_Value ("info.permissions", Permission_Text (To_String (Info.Permissions))),
                     Muted_Text_Color);
               end if;
               if Info.Metadata_Error then
                  Add_Info_Text
                    (6,
                     Info_Value
                       ("info.metadata_error",
                        Files.Localization.Text (To_String (Info.Error_Key))),
                     Muted_Text_Color);
               else
                  Add_Info_Text (6, Missing_Info ("info.metadata_error"), Muted_Text_Color);
               end if;
               Add_Info_Text (7, Info_Value ("info.kind", To_String (Info.Filetype_Detail)), Muted_Text_Color);
               Add_Info_Text (8, Info_Value ("info.extra", To_String (Info.Filetype_Extra)), Muted_Text_Color);
               declare
                  Section_H : constant Natural :=
                    Natural'Min
                      (Saturating_Multiply (Line_Height, Info_Rows_Per_Item),
                       Info_Pane.Height);
                  Visible_Y : constant Integer := Integer'Max (Row_Y, Integer (Info_Pane.Y));
                  Raw_Bottom : constant Integer :=
                    Integer'Min
                      (Saturating_Integer_Add (Row_Y, Section_H),
                       Integer (Info_Bottom));
                  Visible_H : constant Natural :=
                    (if Raw_Bottom > Visible_Y then Natural (Raw_Bottom - Visible_Y) else 0);
                  Size_Text : constant String :=
                    (if Info.Size_Available
                     then Integer_Text (Info.Size)
                     else Files.Localization.Text ("status.missing_metadata"));
                  Modified_Text : constant String :=
                    To_String (Time_Text (Info.Modified_Available, Info.Modified_Time, "info.modified"));
                  Description : Unbounded_String :=
                    To_Unbounded_String
                      (Files.Localization.Text ("info.filetype") & ": " & To_String (Info.Filetype) & ", " &
                       Files.Localization.Text ("info.size") & ": " & Size_Text & ", " &
                       Modified_Text);
               begin
                  if Info.Metadata_Error then
                     Append
                       (Description,
                        ", " &
                        Files.Localization.Text ("info.metadata_error") & ": " &
                        Files.Localization.Text (To_String (Info.Error_Key)));
                  end if;

                  Add_Accessibility_Node
                    (Role_List_Item,
                     Info_Pane.X,
                     Natural (Visible_Y),
                     Text_W,
                     Visible_H,
                     Info.Name,
                     Description);
               end;
            end;
         end loop;

         if Info_Pane.Scrollbar_Visible then
            Add_Scrollbar
              (Info_Pane.Scrollbar_X,
               Info_Pane.Scrollbar_Y,
               Info_Pane.Scrollbar_Width,
               Info_Pane.Height,
               Info_Pane.Scrollbar_Thumb_Y,
               Info_Pane.Scrollbar_Height);
         end if;
      end if;

      if Snapshot.Settings_Pane_Open then
         declare
            Pane_W : constant Natural := Natural'Max (240, Scaled_Down (Width, 2, 5));
            Pane_H : constant Natural := Natural'Max (Saturating_Multiply (Line_Height, 23), Height / 3);
            Pane_X : constant Natural := (if Width > Pane_W then (Width - Pane_W) / 2 else 0);
            Pane_Y : constant Natural :=
              (if Height > Pane_H
               then Natural'Max (Saturating_Add (Layout.Toolbar_Height, 8), Height / 6)
               else Layout.Toolbar_Height);
            Text_X : constant Natural := Saturating_Add (Pane_X, 8);
            Text_W : constant Natural := (if Pane_W > 16 then Pane_W - 16 else 0);

            procedure Add_Settings_Row
              (Row   : Natural;
               Key   : String;
               Color : Render_Color := Muted_Text_Color)
            is
               Y : constant Natural := Saturating_Add (Pane_Y, Saturating_Multiply (Row, Line_Height));
            begin
               Add_Text
                 (Text_X,
                  Y,
                  Text_W,
                  Line_Height,
                  To_Unbounded_String (Files.Localization.Text (Key)),
                  Color,
                  Fit => True);
            end Add_Settings_Row;

            procedure Add_Settings_Value
              (Row   : Natural;
               Key   : String;
               Value : UString;
               Index : Natural)
            is
               Y : constant Natural := Saturating_Add (Pane_Y, Saturating_Multiply (Row, Line_Height));
            begin
               if Snapshot.Settings_Field_Index = Index then
                  Add_Rect (Text_X - 2, Y, Text_W + 4, Line_Height, Selection_Color);
                  Add_Focus_Ring (Text_X - 2, Y, Text_W + 4, Line_Height);
                  Add_Rect
                    (Text_X - 2,
                     Y,
                     Natural'Min (3, Text_W + 4),
                     Line_Height,
                     Border_Color);
               end if;
               Add_Text
                 (Text_X,
                  Y,
                  Text_W,
                  Line_Height,
                  To_Unbounded_String (Files.Localization.Text (Key) & ": " & To_String (Value)),
                  Muted_Text_Color,
                  Fit => True);
            end Add_Settings_Value;

            procedure Add_Settings_Control_Options (Row : Natural) is
               Y : constant Natural := Saturating_Add (Pane_Y, Saturating_Multiply (Row, Line_Height));
               Cell_W : constant Natural := (if Text_W > 0 then Text_W / 4 else 0);

               procedure Add_Cell
                 (Offset : Natural;
                  Key    : String;
                  Active : Boolean)
               is
                  Offset_X : constant Natural := Saturating_Multiply (Offset, Cell_W);
                  X        : constant Natural := Saturating_Add (Text_X, Offset_X);
                  W        : constant Natural := (if Offset = 3 then Text_W - Offset_X else Cell_W);
               begin
                  if W = 0 then
                     return;
                  end if;

                  Add_Rect (X, Y, W, Line_Height, (if Active then Selection_Color else Input_Color));
                  Add_Border (X, Y, W, Line_Height, Border_Color);
                  Add_Text
                    (X + 2,
                     Y,
                     (if W > 4 then W - 4 else 0),
                     Line_Height,
                     To_Unbounded_String (Files.Localization.Text (Key)),
                     Muted_Text_Color,
                     Fit => True);
               end Add_Cell;

               Current : constant String := To_String (Snapshot.Settings_Sort_Field_Token);
            begin
               case Snapshot.Settings_Field_Index is
                  when 1 =>
                     Add_Cell (0, "command.view.small", Snapshot.Settings_Default_View_Token = "small_icons");
                     Add_Cell (1, "command.view.large", Snapshot.Settings_Default_View_Token = "large_icons");
                     Add_Cell (2, "command.view.details", Snapshot.Settings_Default_View_Token = "details");
                  when 2 =>
                     Add_Cell (0, "settings.value.true", Snapshot.Settings_Hidden_Files_Token = "true");
                     Add_Cell (1, "settings.value.false", Snapshot.Settings_Hidden_Files_Token = "false");
                  when 3 =>
                     Add_Cell (0, "settings.value.true", Snapshot.Settings_Sort_Dirs_Token = "true");
                     Add_Cell (1, "settings.value.false", Snapshot.Settings_Sort_Dirs_Token = "false");
                  when 4 =>
                     Add_Cell (0, "settings.sort.name", Current = "name");
                     Add_Cell (1, "settings.sort.filetype", Current = "filetype");
                     Add_Cell (2, "settings.sort.size", Current = "size");
                     Add_Cell (3, "settings.sort.modified", Current = "modified");
                  when 5 =>
                     Add_Cell (0, "settings.value.true", Snapshot.Settings_Sort_Ascending_Token = "true");
                     Add_Cell (1, "settings.value.false", Snapshot.Settings_Sort_Ascending_Token = "false");
                  when 6 =>
                     Add_Cell (0, "settings.value.true", Snapshot.Settings_High_Contrast_Token = "true");
                     Add_Cell (1, "settings.value.false", Snapshot.Settings_High_Contrast_Token = "false");
                  when 7 =>
                     Add_Cell (0, "settings.icon_theme.basic", Snapshot.Settings_Icon_Theme = "files-basic");
                     Add_Cell
                       (1,
                        "settings.icon_theme.high_contrast",
                        Snapshot.Settings_Icon_Theme = "files-high-contrast");
                  when others =>
                     null;
               end case;
            end Add_Settings_Control_Options;

            procedure Add_Settings_Entry_Buttons (Row : Natural) is
               Button_W : constant Natural := 34;
               Gap      : constant Natural := 4;
               Total_W  : constant Natural := Button_W * 2 + Gap;
               Y        : constant Natural := Saturating_Add (Pane_Y, Saturating_Multiply (Row, Line_Height));
               X        : constant Natural :=
                 (if Pane_W > Total_W + 8 then Pane_X + Pane_W - Total_W - 8 else Pane_X);

               procedure Add_Button
                 (Offset : Natural;
                  Key    : String) is
                  Button_X : constant Natural :=
                    Saturating_Add (X, Saturating_Multiply (Offset, Button_W + Gap));
               begin
                  Add_Rect (Button_X, Y, Button_W, Line_Height, Input_Color);
                  Add_Border (Button_X, Y, Button_W, Line_Height, Border_Color);
                  Add_Text
                    (Saturating_Add (Button_X, 2),
                     Y,
                     Button_W - 4,
                     Line_Height,
                     To_Unbounded_String (Files.Localization.Text (Key)),
                     Muted_Text_Color,
                     Fit => True);
                  Add_Tooltip (Button_X, Y, Button_W, Line_Height, Key);
                  Add_Accessibility_Node
                    (Role_Button,
                     Button_X,
                     Y,
                     Button_W,
                     Line_Height,
                     Localized (Key));
               end Add_Button;
            begin
               Add_Button (0, "settings.add");
               Add_Button (1, "settings.remove");
            end Add_Settings_Entry_Buttons;

            procedure Add_Settings_Action_Buttons (Row : Natural) is
               Gap      : constant Natural := 4;
               Base_Button_W : constant Natural := (if Text_W > Gap then (Text_W - Gap) / 2 else 0);
               Second_Button_W : constant Natural :=
                 (if Text_W > Saturating_Add (Base_Button_W, Gap)
                  then Text_W - Saturating_Add (Base_Button_W, Gap)
                  else 0);

               procedure Add_Button
                 (Column  : Natural;
                  Line    : Natural;
                  Command : Files.Commands.Registered_Command_Id;
                  Enabled : Boolean)
               is
                  Button_W : constant Natural := (if Column = 0 then Base_Button_W else Second_Button_W);
                  X : constant Natural :=
                    Saturating_Add (Text_X, Saturating_Multiply (Column, Base_Button_W + Gap));
                  Y : constant Natural :=
                    Saturating_Add
                      (Pane_Y,
                       Saturating_Multiply (Saturating_Add (Row, Line), Line_Height));
               begin
                  if Button_W = 0 then
                     return;
                  end if;

                  Add_Rect (X, Y, Button_W, Line_Height, (if Enabled then Input_Color else Pane_Color));
                  Add_Border (X, Y, Button_W, Line_Height, Border_Color);
                  Add_Text
                    (X + 2,
                     Y,
                     (if Button_W > 4 then Button_W - 4 else 0),
                     Line_Height,
                     Command_Label (Command),
                     (if Enabled then Muted_Text_Color else Disabled_Text_Color),
                     Fit => True);
                  Add_Tooltip
                    (X,
                     Y,
                     Button_W,
                     Line_Height,
                     Files.Commands.Description_Key (Command));
                  Add_Accessibility_Node
                    (Role_Button,
                     X,
                     Y,
                     Button_W,
                     Line_Height,
                     Command_Label (Command),
                     Localized (Files.Commands.Description_Key (Command)),
                     Enabled => Enabled);
               end Add_Button;
            begin
               Add_Button (0, 0, Files.Commands.Import_Settings_Command, Snapshot.Settings_Can_Import);
               Add_Button (1, 0, Files.Commands.Export_Settings_Command, Snapshot.Settings_Can_Export);
               Add_Button (0, 1, Files.Commands.Reset_Settings_Command, Snapshot.Settings_Can_Reset);
               Add_Button (1, 1, Files.Commands.Save_Settings_Command, Snapshot.Settings_Can_Save);
            end Add_Settings_Action_Buttons;
         begin
            Add_Drop_Shadow (Pane_X, Pane_Y, Pane_W, Pane_H);
            Add_Rect (Pane_X, Pane_Y, Pane_W, Pane_H, Overlay_Color);
            Add_Border (Pane_X, Pane_Y, Pane_W, Pane_H, Border_Color);
            Add_Rect (Pane_X, Pane_Y, Pane_W, Natural'Min (3, Pane_H), Selection_Color);
            Add_Accessibility_Node
              (Role_Dialog,
               Pane_X,
               Pane_Y,
               Pane_W,
               Pane_H,
               Localized ("settings.title"));
            Add_Settings_Row (0, "settings.title", Text_Color);
            Add_Settings_Action_Buttons (1);
            Add_Settings_Value (3, "settings.default_view", Snapshot.Settings_Default_View, 1);
            Add_Settings_Value (4, "settings.hidden_files", Snapshot.Settings_Hidden_Files, 2);
            Add_Settings_Value (5, "settings.sort_directories_first", Snapshot.Settings_Sort_Dirs, 3);
            Add_Settings_Value (6, "settings.sort", Snapshot.Settings_Sort, 4);
            Add_Settings_Value (7, "settings.sort_ascending", Snapshot.Settings_Sort_Ascending, 5);
            Add_Settings_Value (8, "settings.high_contrast_theme", Snapshot.Settings_High_Contrast, 6);
            Add_Settings_Value (9, "settings.icon_theme", Snapshot.Settings_Icon_Theme, 7);
            Add_Settings_Value (10, "settings.filetypes", Snapshot.Settings_Filetypes, 0);
            Add_Settings_Entry_Buttons (10);
            Add_Settings_Value (11, "settings.filetype_extension", Snapshot.Settings_Filetype_Extension, 8);
            Add_Settings_Value (12, "settings.filetype_value", Snapshot.Settings_Filetype_Value, 9);
            Add_Settings_Value (13, "settings.icons", Snapshot.Settings_Icons, 0);
            Add_Settings_Entry_Buttons (13);
            Add_Settings_Value (14, "settings.icon_filetype", Snapshot.Settings_Icon_Filetype, 10);
            Add_Settings_Value (15, "settings.icon_value", Snapshot.Settings_Icon_Value, 11);
            Add_Settings_Value (16, "settings.open_actions", Snapshot.Settings_Open_Actions, 0);
            Add_Settings_Entry_Buttons (16);
            Add_Settings_Value (17, "settings.open_action_token", Snapshot.Settings_Open_Action_Token, 12);
            Add_Settings_Value (18, "settings.open_action_command", Snapshot.Settings_Open_Action_Command, 13);
            if Length (Snapshot.Settings_Field_Help) > 0 then
               Add_Text
                 (Text_X,
                  Saturating_Add (Pane_Y, Saturating_Multiply (19, Line_Height)),
                  Text_W,
                  Line_Height,
                  Snapshot.Settings_Field_Help,
                  Muted_Text_Color,
                  Fit => True);
            end if;
            if Length (Snapshot.Settings_Control_Options) > 0 then
               Add_Text
                 (Text_X,
                  Saturating_Add (Pane_Y, Saturating_Multiply (20, Line_Height)),
                  Text_W,
                  Line_Height,
                  Snapshot.Settings_Control_Options,
                  Muted_Text_Color,
                  Fit => True);
            end if;
            if Snapshot.Settings_Field_Index in 1 .. 7 then
               Add_Settings_Control_Options (21);
            end if;
            if not Snapshot.Settings_Draft_Valid and then Length (Snapshot.Settings_Draft_Error) > 0 then
               Add_Settings_Row (22, To_String (Snapshot.Settings_Draft_Error), Error_Text_Color);
            end if;
         end;
      end if;

      if Snapshot.Command_Palette_Open then
         Add_Drop_Shadow (Palette.X, Palette.Y, Palette.Width, Palette.Height);
         Add_Rect (Palette.X, Palette.Y, Palette.Width, Palette.Height, Overlay_Color);
         Add_Border (Palette.X, Palette.Y, Palette.Width, Palette.Height, Border_Color);
         Add_Rect (Palette.X, Palette.Y, Palette.Width, Natural'Min (3, Palette.Height), Selection_Color);
         Add_Accessibility_Node
           (Role_Dialog,
            Palette.X,
            Palette.Y,
            Palette.Width,
            Palette.Height,
            Localized ("command.palette.open"));
         Add_Rect (Palette.Search_X, Palette.Search_Y, Palette.Search_Width, Palette.Search_Height, Input_Color);
         Add_Text
           (Palette.Search_X + 4,
            Palette.Search_Y,
            (if Palette.Search_Width > 8 then Palette.Search_Width - 8 else 0),
            Palette.Search_Height,
            Snapshot.Command_Palette_Query,
            Fit => True);
         if Snapshot.Focus = Files.Types.Focus_Command_Palette then
            Add_Border
              (Palette.Search_X,
               Palette.Search_Y,
               Palette.Search_Width,
               Palette.Search_Height,
               Border_Color);
            Add_Focus_Ring
              (Palette.Search_X,
               Palette.Search_Y,
               Palette.Search_Width,
               Palette.Search_Height);
            Add_Caret (Palette.Search_X, Palette.Search_Y, Palette.Search_Width, Palette.Search_Height);
         end if;
         Add_Accessibility_Node
           (Role_Text_Input,
            Palette.Search_X,
            Palette.Search_Y,
            Palette.Search_Width,
            Palette.Search_Height,
            Localized ("accessibility.command_palette_search"),
            Snapshot.Command_Palette_Query,
            Focused => Snapshot.Focus = Files.Types.Focus_Command_Palette);

         if Snapshot.Command_Palette_Results.Is_Empty and then Palette.Results_Height > 0 then
            Add_Rect
              (Palette.Results_X,
               Palette.Results_Y,
               Palette.Results_Width,
               Natural'Min (Saturating_Multiply (Line_Height, 2), Palette.Results_Height),
               Pane_Color);
            Add_Border
              (Palette.Results_X,
               Palette.Results_Y,
               Palette.Results_Width,
               Natural'Min (Saturating_Multiply (Line_Height, 2), Palette.Results_Height),
               Border_Color);
            Add_Text
              (Saturating_Add (Palette.Results_X, 8),
               Palette.Results_Y,
               (if Palette.Results_Width > 16 then Palette.Results_Width - 16 else Palette.Results_Width),
               Natural'Min (Line_Height, Palette.Results_Height),
               Localized ("command.palette.empty"),
               Muted_Text_Color,
               Fit => True);
            Add_Accessibility_Node
              (Role_Status,
               Palette.Results_X,
               Palette.Results_Y,
               Palette.Results_Width,
               Natural'Min (Saturating_Multiply (Line_Height, 2), Palette.Results_Height),
               Localized ("command.palette.empty"));
         end if;

         for Index in 1 .. Natural (Palette_Rows.Length) loop
            declare
               Row     : constant Command_Result_Layout := Palette_Rows.Element (Positive (Index));
               Command : constant Command_Result_Snapshot :=
                 Snapshot.Command_Palette_Results.Element (Positive (Row.Result_Index));
               Accessible_Description : constant UString :=
                 Command_Result_Accessible_Description (Command);
               Shortcut_Width : constant Natural :=
                 (if Length (Command.Shortcut_Text) = 0 then 0
                  else Natural'Min
                    (Natural'Min
                       (Saturating_Multiply (Length (Command.Shortcut_Text), Line_Height / 2),
                        160),
                     (if Row.Width > 16 then Row.Width / 3 else 0)));
               Label_Width : constant Natural :=
                 (if Row.Width <= 8 then 0
                  elsif Shortcut_Width = 0 then Row.Width - 8
                  elsif Row.Width > Shortcut_Width + 16 then Row.Width - Shortcut_Width - 16
                  else 0);
               Hovered : constant Boolean :=
                 Has_Hover and then Contains_Point (Row.X, Row.Y, Row.Width, Row.Height, Hover_X, Hover_Y);
               Pressed : constant Boolean := Is_Pressed (Row.X, Row.Y, Row.Width, Row.Height);
            begin
               Add_Rect
                 (Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  (if Row.Selected and then Row.Enabled then Selection_Color
                   elsif Pressed then Pressed_Color
                   elsif Hovered then Hover_Color
                   elsif not Row.Enabled then Pane_Color
                   else Overlay_Color));
               if Row.Selected then
                  Add_Rect
                    (Row.X,
                     Row.Y,
                     Natural'Min (3, Row.Width),
                     Row.Height,
                     Border_Color);
               end if;
               if not Row.Enabled and then Row.Height > 0 then
                  Add_Rect
                    (Saturating_Add (Row.X, 4),
                     Saturating_Add (Row.Y, Natural'Min (Row.Height - 1, Line_Height - 1)),
                     (if Row.Width > 8 then Row.Width - 8 else 0),
                     1,
                     Disabled_Text_Color);
               end if;
               Add_Text
                 (Saturating_Add (Row.X, 4),
                  Row.Y,
                  Label_Width,
                  Natural'Min (Line_Height, Row.Height),
                  Command.Label,
                  (if Row.Enabled then Text_Color else Disabled_Text_Color),
                  Fit => True);
               if Shortcut_Width > 0 then
                  Add_Text
                    (Saturating_Add (Row.X, Row.Width - Shortcut_Width - 4),
                     Row.Y,
                     Shortcut_Width,
                     Natural'Min (Line_Height, Row.Height),
                     Command.Shortcut_Text,
                     (if Row.Enabled then Muted_Text_Color else Disabled_Text_Color),
                     Fit => True);
               end if;
               if Row.Height > Line_Height then
                  Add_Text
                    (Saturating_Add (Row.X, 4),
                     Saturating_Add (Row.Y, Line_Height),
                     (if Row.Width > 8 then Row.Width - 8 else 0),
                     Natural'Min (Line_Height, Row.Height - Line_Height),
                     Command.Description,
                     (if Row.Enabled then Muted_Text_Color else Disabled_Text_Color),
                  Fit => True);
               end if;
               Add_Accessibility_Node
                 (Role_List_Item,
                  Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  Command.Label,
                  Accessible_Description,
                  Enabled  => Row.Enabled,
                  Selected => Row.Selected,
                  Focused  => Row.Selected);
            end;
         end loop;

         Add_Palette_Scrollbar;
      end if;

      if Snapshot.Root_Selector_Open then
         Add_Drop_Shadow
           (Root_Selector.X,
            Root_Selector.Y,
            Root_Selector.Width,
            Root_Selector.Height);
         Add_Rect
           (Root_Selector.X,
            Root_Selector.Y,
            Root_Selector.Width,
            Root_Selector.Height,
            Overlay_Color);
         Add_Border
           (Root_Selector.X,
            Root_Selector.Y,
            Root_Selector.Width,
            Root_Selector.Height,
            Border_Color);
         Add_Accessibility_Node
           (Role_List,
            Root_Selector.X,
            Root_Selector.Y,
            Root_Selector.Width,
            Root_Selector.Height,
            Localized ("accessibility.root_selector"));

         for Index in 1 .. Natural (Root_Rows.Length) loop
            declare
               Row       : constant Root_Path_Layout := Root_Rows.Element (Positive (Index));
               Glyph_Size : constant Natural :=
                 (if Row.Height > 6 then Natural'Min (Line_Height, Row.Height) - 4 else 0);
               Glyph_X    : constant Natural := Saturating_Add (Row.X, 4);
               Glyph_Y    : constant Natural :=
                 (if Row.Height > Glyph_Size
                  then Saturating_Add (Row.Y, (Row.Height - Glyph_Size) / 2)
                  else Row.Y);
               Text_X     : constant Natural := Saturating_Add (Row.X, Saturating_Add (Glyph_Size, 10));
               Text_W     : constant Natural :=
                 (if Row.Width > Saturating_Add (Glyph_Size, 14)
                  then Row.Width - Saturating_Add (Glyph_Size, 14)
                  else 0);
               Hovered    : constant Boolean :=
                 Has_Hover and then Contains_Point (Row.X, Row.Y, Row.Width, Row.Height, Hover_X, Hover_Y);
               Pressed    : constant Boolean := Is_Pressed (Row.X, Row.Y, Row.Width, Row.Height);
            begin
               Add_Rect
                 (Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  (if Row.Selected then Selection_Color
                   elsif Pressed then Pressed_Color
                   elsif Hovered then Hover_Color
                   else Overlay_Color));
               if Index > 1 then
                  Add_Rect (Row.X, Row.Y, Row.Width, 1, Border_Color);
               end if;
               if Row.Selected then
                  Add_Rect
                    (Row.X,
                     Row.Y,
                     Natural'Min (3, Row.Width),
                     Row.Height,
                     Border_Color);
               end if;
               if Glyph_Size > 0 then
                  Add_Rect
                    (Glyph_X,
                     Saturating_Add (Glyph_Y, Glyph_Size / 4),
                     Glyph_Size,
                     Natural'Max (1, Glyph_Size / 2),
                     Icon_Directory_Color);
                  Add_Rect
                    (Saturating_Add (Glyph_X, Glyph_Size / 4),
                     Glyph_Y,
                     Natural'Max (1, Glyph_Size / 2),
                     Natural'Max (1, Glyph_Size / 4),
                     Icon_Directory_Color);
               end if;
               Add_Text
                 (Text_X,
                  Row.Y,
                  Text_W,
                  Row.Height,
                  Snapshot.Root_Labels.Element (Positive (Row.Root_Index)),
                  Fit => True);
               Add_Tooltip
                 (Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  Files.Commands.Description_Key (Files.Commands.Open_Selected_Root_Command));
               Add_Accessibility_Node
                 (Role_List_Item,
                  Row.X,
                  Row.Y,
                  Row.Width,
                  Row.Height,
                  Snapshot.Root_Labels.Element (Positive (Row.Root_Index)),
                  Snapshot.Root_Paths.Element (Positive (Row.Root_Index)),
                  Enabled  => True,
                  Selected => Row.Selected,
                  Focused  => Row.Selected);
            end;
         end loop;
      end if;

      Add_Hover_Tooltip;

      return Result;
   end Build_Frame_Commands;

   function Default_Font_Path return String is
   begin
      return "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf";
   end Default_Font_Path;

   function Initialize_Text
     (Renderer     : in out Text_Renderer;
      Font_Path    : String;
      Pixel_Size   : Positive := 16;
      Cell_Width   : Positive := 10;
      Cell_Height  : Positive := 20;
      Atlas_Width  : Positive := 1024;
      Atlas_Height : Positive := 1024)
      return Text_Render_Status
   is
      use type Textrender.Status_Code;
      Status : Textrender.Status_Code;
   begin
      Renderer.Loaded := False;
      Renderer.Font_Path := To_Unbounded_String ("");

      if Font_Path = "" then
         Textrender.Reset;
         return Text_Render_Font_Load_Failed;
      end if;

      Status :=
        Textrender.Load_Font
          (Path         => Font_Path,
           Pixel_Size   => Pixel_Size,
           Cell_Width   => Cell_Width,
           Cell_Height  => Cell_Height,
           Atlas_Width  => Atlas_Width,
           Atlas_Height => Atlas_Height);

      if Status /= Textrender.Success then
         return Text_Render_Font_Load_Failed;
      end if;

      Renderer.Loaded := True;
      Renderer.Font_Path := To_Unbounded_String (Font_Path);
      Renderer.Cell_Width := Cell_Width;
      Renderer.Cell_Height := Cell_Height;
      Renderer.Atlas_Width := Atlas_Width;
      Renderer.Atlas_Height := Atlas_Height;
      return Text_Render_Success;
   end Initialize_Text;

   function Build_Text_Glyphs
     (Renderer : in out Text_Renderer;
      Frame    : Frame_Commands)
      return Text_Render_Result
   is
      use type Textrender.Status_Code;
      Result : Text_Render_Result;
   begin
      if not Renderer.Loaded then
         return Result;
      end if;

      Result.Status := Text_Render_Success;
      Result.Atlas_Width := Renderer.Atlas_Width;
      Result.Atlas_Height := Renderer.Atlas_Height;
      Result.Atlas_Bytes := Saturating_Multiply (Renderer.Atlas_Width, Renderer.Atlas_Height);

      for Text of Frame.Text loop
         declare
            Content : constant String := To_String (Text.Text);
            Cell_X  : Float := Float (Text.X);
            Cell_Y  : constant Float := Float (Text.Y);
            Limit_X : constant Float := Float (Saturating_Add (Text.X, Text.Width));
         begin
            for Character_Value of Content loop
               exit when Cell_X + Float (Renderer.Cell_Width) > Limit_X;

               declare
                  Codepoint : constant Textrender.Codepoint := Character'Pos (Character_Value);
                  Metrics   : Textrender.Glyph_Metric;
                  Placement : Textrender.Glyph_Placement;
                  Status    : constant Textrender.Status_Code := Textrender.Get_Glyph (Codepoint, Metrics);
               begin
                  if Status /= Textrender.Success and then Status /= Textrender.Glyph_Missing then
                     Result.Status := Text_Render_Glyph_Failed;
                     return Result;
                  end if;

                  if Metrics.W > 0.0 and then Metrics.H > 0.0 then
                     Placement := Textrender.Place_Glyph_In_Cell (Metrics, Cell_X, Cell_Y);
                     Result.Glyphs.Append
                       (Glyph_Command'
                          (X         => Placement.X,
                           Y         => Placement.Y,
                           Width     => Metrics.W,
                           Height    => Metrics.H,
                           U0        => Metrics.U0,
                           V0        => Metrics.V0,
                           U1        => Metrics.U1,
                           V1        => Metrics.V1,
                           Color     => Text.Color,
                           Codepoint => Natural (Codepoint)));
                  end if;
               end;

               Cell_X := Cell_X + Float (Renderer.Cell_Width);
            end loop;
         end;
      end loop;

      Result.Atlas_Dirty := Textrender.Atlas_Dirty;
      if Textrender.Atlas_Pixels /= null then
         Result.Atlas_Pixels := Textrender.Atlas_Pixels.all'Address;
      end if;
      return Result;
   end Build_Text_Glyphs;

end Files.Rendering;
