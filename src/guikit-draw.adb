with Ada.Strings;
with Ada.Strings.Fixed;

--  Implementation of the renderer-agnostic draw model helpers.
package body Guikit.Draw is

   use Ada.Strings.Unbounded;

   function Color_For
     (Role  : Render_Color;
      Theme : Theme_Kind := Theme_Dark)
      return Palette_Color
   is
      function RGB
        (R : Float;
         G : Float;
         B : Float;
         A : Float := 1.0)
         return Palette_Color is
      begin
         return (R => R, G => G, B => B, A => A);
      end RGB;

      --  Dark base palette. Theme_High_Contrast reuses these values so its
      --  rendering is unchanged from before the light theme was introduced.
      function Dark_Color return Palette_Color is
      begin
         case Role is
            when Canvas_Color          => return RGB (0.08, 0.09, 0.10);
            when Toolbar_Color         => return RGB (0.07, 0.08, 0.09);
            when Bottom_Bar_Color      => return RGB (0.07, 0.08, 0.09);
            when Main_Color            => return RGB (0.10, 0.11, 0.12);
            when Detail_Alternate_Color => return RGB (0.12, 0.13, 0.14);
            when Pane_Color            => return RGB (0.16, 0.17, 0.18);
            when Input_Color           => return RGB (0.18, 0.19, 0.20);
            when Input_Error_Color     => return RGB (0.44, 0.12, 0.14);
            when Selection_Color       => return RGB (0.21, 0.38, 0.62);
            when Hover_Color           => return RGB (0.20, 0.22, 0.24);
            when Pressed_Color         => return RGB (0.17, 0.24, 0.34);
            when Border_Color          => return RGB (0.28, 0.29, 0.30);
            when Text_Color            => return RGB (0.86, 0.87, 0.88);
            when Muted_Text_Color      => return RGB (0.58, 0.60, 0.62);
            when Error_Text_Color      => return RGB (0.94, 0.30, 0.27);
            when Disabled_Text_Color   => return RGB (0.40, 0.41, 0.42);
            when Icon_Directory_Color  => return RGB (0.32, 0.50, 0.82);
            when Icon_File_Color       => return RGB (0.70, 0.72, 0.74);
            when Icon_Executable_Color => return RGB (0.38, 0.68, 0.42);
            when Icon_Unknown_Color    => return RGB (0.55, 0.55, 0.57);
            when Favorite_Star_Color   => return RGB (0.96, 0.78, 0.28);
            when Label_Red_Color       => return RGB (0.90, 0.30, 0.28);
            when Label_Orange_Color    => return RGB (0.94, 0.58, 0.22);
            when Label_Yellow_Color    => return RGB (0.94, 0.84, 0.30);
            when Label_Green_Color     => return RGB (0.40, 0.74, 0.42);
            when Label_Blue_Color      => return RGB (0.34, 0.56, 0.90);
            when Label_Purple_Color    => return RGB (0.64, 0.44, 0.86);
            when Label_Gray_Color      => return RGB (0.60, 0.62, 0.66);
            when Marquee_Color         => return RGB (0.21, 0.38, 0.62, 0.25);
            when Overlay_Color         => return RGB (0.04, 0.05, 0.06, 0.86);
         end case;
      end Dark_Color;

      --  Light palette: light surfaces, dark text, and selection/hover/border
      --  colors chosen for legible contrast against the light backgrounds.
      function Light_Color return Palette_Color is
      begin
         case Role is
            when Canvas_Color          => return RGB (0.93, 0.94, 0.95);
            when Toolbar_Color         => return RGB (0.88, 0.89, 0.91);
            when Bottom_Bar_Color      => return RGB (0.88, 0.89, 0.91);
            when Main_Color            => return RGB (0.98, 0.98, 0.99);
            when Detail_Alternate_Color => return RGB (0.94, 0.95, 0.96);
            when Pane_Color            => return RGB (0.90, 0.91, 0.93);
            when Input_Color           => return RGB (1.00, 1.00, 1.00);
            when Input_Error_Color     => return RGB (0.98, 0.82, 0.82);
            when Selection_Color       => return RGB (0.62, 0.78, 0.98);
            when Hover_Color           => return RGB (0.84, 0.86, 0.89);
            when Pressed_Color         => return RGB (0.72, 0.82, 0.95);
            when Border_Color          => return RGB (0.68, 0.70, 0.73);
            when Text_Color            => return RGB (0.11, 0.12, 0.14);
            when Muted_Text_Color      => return RGB (0.38, 0.40, 0.43);
            when Error_Text_Color      => return RGB (0.72, 0.10, 0.10);
            when Disabled_Text_Color   => return RGB (0.60, 0.62, 0.64);
            when Icon_Directory_Color  => return RGB (0.18, 0.40, 0.74);
            when Icon_File_Color       => return RGB (0.34, 0.36, 0.40);
            when Icon_Executable_Color => return RGB (0.16, 0.52, 0.24);
            when Icon_Unknown_Color    => return RGB (0.44, 0.44, 0.48);
            when Favorite_Star_Color   => return RGB (0.82, 0.60, 0.08);
            when Label_Red_Color       => return RGB (0.82, 0.20, 0.18);
            when Label_Orange_Color    => return RGB (0.86, 0.48, 0.12);
            when Label_Yellow_Color    => return RGB (0.82, 0.70, 0.14);
            when Label_Green_Color     => return RGB (0.24, 0.60, 0.28);
            when Label_Blue_Color      => return RGB (0.20, 0.44, 0.82);
            when Label_Purple_Color    => return RGB (0.50, 0.30, 0.76);
            when Label_Gray_Color      => return RGB (0.46, 0.48, 0.52);
            when Marquee_Color         => return RGB (0.62, 0.78, 0.98, 0.30);
            when Overlay_Color         => return RGB (0.20, 0.22, 0.26, 0.62);
         end case;
      end Light_Color;
   begin
      case Theme is
         when Theme_Dark          => return Dark_Color;
         when Theme_High_Contrast => return Dark_Color;
         when Theme_Light         => return Light_Color;
      end case;
   end Color_For;

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
      elsif Icon_Id = "thumbnail" then
         return
           Header ("thumbnail")
           & "rect=1,1,14,14,border" & LF
           & "rect=2,2,12,12,base" & LF
           & "rect=3,3,10,7,accent" & LF
           & "rect=4,8,4,2,border" & LF
           & "rect=8,7,4,3,border" & LF
           & "rect=3,12,10,1,muted" & LF;
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
      elsif Icon_Id = "toolbar-home" then
         return
           Header ("toolbar-home")
           & "rect=7,2,2,1,border" & LF
           & "rect=6,3,4,1,border" & LF
           & "rect=5,4,6,1,border" & LF
           & "rect=4,5,8,1,border" & LF
           & "rect=3,6,10,2,border" & LF
           & "rect=4,8,2,5,border" & LF
           & "rect=10,8,2,5,border" & LF
           & "rect=6,12,4,1,border" & LF
           & "rect=7,9,2,4,border" & LF;
      elsif Icon_Id = "toolbar-back" then
         return
           Header ("toolbar-back")
           & "rect=7,3,2,2,border" & LF
           & "rect=6,5,2,2,border" & LF
           & "rect=4,7,8,2,border" & LF
           & "rect=6,9,2,2,border" & LF
           & "rect=7,11,2,2,border" & LF;
      elsif Icon_Id = "toolbar-forward" then
         return
           Header ("toolbar-forward")
           & "rect=7,3,2,2,border" & LF
           & "rect=8,5,2,2,border" & LF
           & "rect=4,7,8,2,border" & LF
           & "rect=8,9,2,2,border" & LF
           & "rect=7,11,2,2,border" & LF;
      elsif Icon_Id = "toolbar-create" then
         return
           Header ("toolbar-create")
           & "rect=7,3,2,10,border" & LF
           & "rect=3,7,10,2,border" & LF;
      elsif Icon_Id = "toolbar-delete" then
         return
           Header ("toolbar-delete")
           & "rect=6,3,4,1,border" & LF
           & "rect=4,5,8,2,border" & LF
           & "rect=5,7,1,6,border" & LF
           & "rect=10,7,1,6,border" & LF
           & "rect=5,12,6,1,border" & LF
           & "rect=7,8,1,4,border" & LF
           & "rect=9,8,1,4,border" & LF;
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

end Guikit.Draw;
