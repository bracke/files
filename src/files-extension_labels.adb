with Ada.Containers;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Interfaces;
with System;
with System.Address_To_Access_Conversions;

with Files.Fonts;
with Guikit.Text;

package body Files.Extension_Labels is

   use type System.Address;
   use type Interfaces.Unsigned_8;
   use type Guikit.Draw.Text_Render_Status;

   --  Matches the renderer's atlas cap; the atlas is a single-channel (R8) alpha
   --  buffer, so one byte per pixel.
   Max_Atlas_Bytes : constant := 4_194_304;
   type Atlas_Bytes_Array is array (Positive range 1 .. Max_Atlas_Bytes) of Interfaces.Unsigned_8;
   package Atlas_Conversions is new System.Address_To_Access_Conversions (Atlas_Bytes_Array);

   package Label_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Label,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Cache          : Label_Maps.Map;
   R              : Guikit.Text.Renderer;
   R_Pixel_Height : Natural := 0;

   function Theme_Tag (Theme : Guikit.Draw.Theme_Kind) return String is
     (case Theme is
         when Guikit.Draw.Theme_Dark          => "d",
         when Guikit.Draw.Theme_Light          => "l",
         when Guikit.Draw.Theme_High_Contrast => "h");

   function To_Byte (Channel : Float) return Interfaces.Unsigned_8 is
     (Interfaces.Unsigned_8 (Natural'Min (255, Natural (Float'Max (0.0, Channel) * 255.0))));

   --  (Re)load the small renderer at Height. The cached bitmaps were rendered at
   --  the previous height, so drop them when the height changes.
   procedure Ensure_Renderer (Height : Positive) is
      Fallbacks : Guikit.Text.Font_Path_Vectors.Vector;
      Status    : Guikit.Draw.Text_Render_Status;
      pragma Unreferenced (Status);
   begin
      if R_Pixel_Height = Height and then Guikit.Text.Loaded (R) then
         return;
      end if;
      for Path of Files.Fonts.Fallback_Font_Paths loop
         Fallbacks.Append (Ada.Strings.Unbounded.To_String (Path));
      end loop;
      Status :=
        Guikit.Text.Initialize
          (R              => R,
           Font_Path      => Files.Fonts.Default_Font_Path,
           Fallback_Paths => Fallbacks,
           Pixel_Size     => Height,
           Cell_Width     => Positive'Max (1, Height * 3 / 5),
           Cell_Height    => Height);
      R_Pixel_Height := Height;
      Cache.Clear;
   end Ensure_Renderer;

   function Rasterize
     (Ext    : String;
      Height : Positive;
      Theme  : Guikit.Draw.Theme_Kind)
      return Label
   is
      use Guikit.Draw;
      Cmd    : Text_Command_Vectors.Vector;
      Empty  : Text_Command_Vectors.Vector;
      Result : Text_Render_Result;
      Color  : constant Palette_Color := Color_For (Canvas_Color, Theme);
      Cr     : constant Interfaces.Unsigned_8 := To_Byte (Color.R);
      Cg     : constant Interfaces.Unsigned_8 := To_Byte (Color.G);
      Cb     : constant Interfaces.Unsigned_8 := To_Byte (Color.B);
   begin
      Cmd.Append
        (Text_Command'
           (X             => 0,
            Y             => 0,
            Width         => Positive'Max (1, Ext'Length * Height * 2),
            Height        => Height,
            Text          => Ada.Strings.Unbounded.To_Unbounded_String (Ext),
            Color         => Canvas_Color,
            Truncated     => False,
            Scale_To_Box  => False,
            Italic        => False));
      Result := Guikit.Text.Build_Glyphs (R, Cmd, Empty);
      if Result.Status /= Text_Render_Success
        or else Result.Glyphs.Is_Empty
        or else Result.Atlas_Pixels = System.Null_Address
        or else Result.Atlas_Width = 0
        or else Result.Atlas_Height = 0
      then
         return (Width => 0, Height => 0, Pixels => Byte_Vectors.Empty_Vector);
      end if;

      declare
         AW    : constant Natural := Result.Atlas_Width;
         AH    : constant Natural := Result.Atlas_Height;
         Atlas : constant Atlas_Conversions.Object_Pointer :=
           Atlas_Conversions.To_Pointer (Result.Atlas_Pixels);
         W0    : Natural := 0;
         H0    : Natural := 0;
      begin
         for G of Result.Glyphs loop
            W0 := Natural'Max (W0, Natural (Float'Ceiling (G.X + G.Width)));
            H0 := Natural'Max (H0, Natural (Float'Ceiling (G.Y + G.Height)));
         end loop;
         if W0 = 0 or else H0 = 0 then
            return (Width => 0, Height => 0, Pixels => Byte_Vectors.Empty_Vector);
         end if;

         declare
            Buf   : Byte_Vectors.Vector :=
              Byte_Vectors.To_Vector (0, Ada.Containers.Count_Type (W0 * H0 * 4));
            Min_C : Natural := W0;
            Max_C : Natural := 0;
            Min_R : Natural := H0;
            Max_R : Natural := 0;
            Inked : Boolean := False;
         begin
            --  Composite every glyph into a scratch buffer, tracking the inked bounds.
            for G of Result.Glyphs loop
               declare
                  SX0 : constant Natural := Natural (Float'Floor (G.U0 * Float (AW)));
                  SY0 : constant Natural := Natural (Float'Floor (G.V0 * Float (AH)));
                  GW  : constant Natural := Natural (Float'Rounding (G.Width));
                  GH  : constant Natural := Natural (Float'Rounding (G.Height));
                  DX0 : constant Natural := Natural (Float'Rounding (G.X));
                  DY0 : constant Natural := Natural (Float'Rounding (G.Y));
               begin
                  for Y in 0 .. GH - 1 loop
                     for X in 0 .. GW - 1 loop
                        declare
                           SX    : constant Natural := SX0 + X;
                           SY    : constant Natural := SY0 + Y;
                           DX    : constant Natural := DX0 + X;
                           DY    : constant Natural := DY0 + Y;
                           A_Idx : constant Natural := SY * AW + SX + 1;
                        begin
                           if DX < W0 and then DY < H0
                             and then SX < AW and then SY < AH
                             and then A_Idx <= Result.Atlas_Bytes
                           then
                              declare
                                 Alpha : constant Interfaces.Unsigned_8 := Atlas.all (A_Idx);
                                 P     : constant Positive := Positive ((DY * W0 + DX) * 4 + 1);
                              begin
                                 if Alpha > 0 then
                                    Buf.Replace_Element (P, Cr);
                                    Buf.Replace_Element (P + 1, Cg);
                                    Buf.Replace_Element (P + 2, Cb);
                                    Buf.Replace_Element (P + 3, Alpha);
                                    Min_C := Natural'Min (Min_C, DX);
                                    Max_C := Natural'Max (Max_C, DX);
                                    Min_R := Natural'Min (Min_R, DY);
                                    Max_R := Natural'Max (Max_R, DY);
                                    Inked := True;
                                 end if;
                              end;
                           end if;
                        end;
                     end loop;
                  end loop;
               end;
            end loop;

            if not Inked then
               return (Width => 0, Height => 0, Pixels => Byte_Vectors.Empty_Vector);
            end if;

            --  Crop to the inked bounds so no transparent margin remains on any side.
            declare
               CW : constant Natural := Max_C - Min_C + 1;
               CH : constant Natural := Max_R - Min_R + 1;
            begin
               return Out_Label : Label do
                  Out_Label.Width  := CW;
                  Out_Label.Height := CH;
                  Out_Label.Pixels :=
                    Byte_Vectors.To_Vector (0, Ada.Containers.Count_Type (CW * CH * 4));
                  for Row in 0 .. CH - 1 loop
                     for Col in 0 .. CW - 1 loop
                        declare
                           Src : constant Positive :=
                             Positive (((Row + Min_R) * W0 + (Col + Min_C)) * 4 + 1);
                           Dst : constant Positive := Positive ((Row * CW + Col) * 4 + 1);
                        begin
                           Out_Label.Pixels.Replace_Element (Dst, Buf.Element (Src));
                           Out_Label.Pixels.Replace_Element (Dst + 1, Buf.Element (Src + 1));
                           Out_Label.Pixels.Replace_Element (Dst + 2, Buf.Element (Src + 2));
                           Out_Label.Pixels.Replace_Element (Dst + 3, Buf.Element (Src + 3));
                        end;
                     end loop;
                  end loop;
               end return;
            end;
         end;
      end;
   end Rasterize;

   function Label_For
     (Ext    : String;
      Height : Natural;
      Theme  : Guikit.Draw.Theme_Kind)
      return Label
   is
      Key : constant String := Theme_Tag (Theme) & ":" & Ext;
   begin
      if Ext = "" or else Height < 1 then
         return (Width => 0, Height => 0, Pixels => Files.Types.Byte_Vectors.Empty_Vector);
      end if;
      Ensure_Renderer (Height);
      if not Guikit.Text.Loaded (R) then
         return (Width => 0, Height => 0, Pixels => Files.Types.Byte_Vectors.Empty_Vector);
      end if;
      if not Cache.Contains (Key) then
         Cache.Insert (Key, Rasterize (Ext, Height, Theme));
      end if;
      return Cache.Element (Key);
   end Label_For;

end Files.Extension_Labels;
