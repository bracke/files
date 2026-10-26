with Ada.Containers;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Real_Time;
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

   --  The renderer's atlas cap; the atlas is a single-channel (R8) alpha
   --  buffer, so one byte per pixel.
   Max_Atlas_Bytes : constant := Guikit.Draw.Max_Atlas_Bytes;
   type Atlas_Bytes_Array is array (Positive range 1 .. Max_Atlas_Bytes) of Interfaces.Unsigned_8;
   package Atlas_Conversions is new System.Address_To_Access_Conversions (Atlas_Bytes_Array);

   package Label_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Label,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  Bound the cache so browsing directories full of arbitrary distinct
   --  suffixes (hex hashes, numbered .0001 parts) cannot grow it without limit --
   --  each entry holds a rasterized alpha bitmap. Real use (a few dozen
   --  extensions x three themes) stays well under this; only the pathological
   --  case reaches it, and then re-rasterizes on demand after a reset.
   Max_Cached_Labels : constant := 512;

   Cache          : Label_Maps.Map;
   R              : Guikit.Text.Renderer;
   R_Pixel_Height : Natural := 0;
   --  Height whose initialization last failed, and when. Retrying it for
   --  every label drawn reloaded and parsed each fallback font from disk per
   --  call; it is tried again after a pause (a font installed meanwhile, a
   --  disk that was not ready), as the windows retry their own text.
   Failed_Height  : Natural := 0;
   Failed_At      : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   Retry_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (5);

   function Theme_Tag (Theme : Guikit.Draw.Theme_Kind) return String is
     (case Theme is
         when Guikit.Draw.Theme_Dark          => "d",
         when Guikit.Draw.Theme_Light          => "l",
         when Guikit.Draw.Theme_High_Contrast => "h");

   function To_Byte (Channel : Float) return Interfaces.Unsigned_8 is
     (Interfaces.Unsigned_8 (Natural'Min (255, Natural (Float'Max (0.0, Channel) * 255.0))));

   --  (Re)load the small renderer at Height. The cache is keyed by height, so
   --  labels made at another (another window's zoom) stay cached.
   procedure Ensure_Renderer (Height : Positive) is
      use type Ada.Real_Time.Time;
      Fallbacks : Guikit.Text.Font_Path_Vectors.Vector;
      Status    : Guikit.Draw.Text_Render_Status;
      pragma Unreferenced (Status);
   begin
      if R_Pixel_Height = Height and then Guikit.Text.Loaded (R) then
         return;
      elsif Failed_Height = Height and then Ada.Real_Time.Clock < Failed_At + Retry_Interval then
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
      Failed_Height := (if Guikit.Text.Loaded (R) then 0 else Height);
      Failed_At := Ada.Real_Time.Clock;
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
        or else Result.Atlas_Bytes = 0
        or else Result.Atlas_Bytes > Max_Atlas_Bytes
        or else Result.Atlas_Width > Result.Atlas_Bytes / Result.Atlas_Height
      then
         return (Width => 0, Height => 0, Pixels => Files.Shared_Bytes.Empty);
      end if;

      declare
         AW    : constant Natural := Result.Atlas_Width;
         AH    : constant Natural := Result.Atlas_Height;
         Atlas : constant Atlas_Conversions.Object_Pointer :=
           Atlas_Conversions.To_Pointer (Result.Atlas_Pixels);
         W0    : Natural := 0;
         H0    : Natural := 0;
      begin
         --  A glyph can start left of or above the origin (a negative bearing):
         --  coordinates are clamped at zero rather than raising.
         for G of Result.Glyphs loop
            W0 := Natural'Max (W0, Natural (Float'Ceiling (Float'Max (0.0, G.X + G.Width))));
            H0 := Natural'Max (H0, Natural (Float'Ceiling (Float'Max (0.0, G.Y + G.Height))));
         end loop;
         if W0 = 0 or else H0 = 0
           or else W0 > Max_Atlas_Bytes / 4
           or else H0 > Max_Atlas_Bytes / (W0 * 4)
         then
            return (Width => 0, Height => 0, Pixels => Files.Shared_Bytes.Empty);
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
                  --  The glyph's own pixels when it says where they are: the
                  --  atlas may have grown taller while this text was packed.
                  SX0 : constant Natural :=
                    (if G.Atlas_W > 0 then G.Atlas_X else Natural (Float'Floor (G.U0 * Float (AW))));
                  SY0 : constant Natural :=
                    (if G.Atlas_W > 0 then G.Atlas_Y else Natural (Float'Floor (G.V0 * Float (AH))));
                  GW  : constant Natural := Natural (Float'Rounding (Float'Max (0.0, G.Width)));
                  GH  : constant Natural := Natural (Float'Rounding (Float'Max (0.0, G.Height)));
                  DX0 : constant Natural := Natural (Float'Rounding (Float'Max (0.0, G.X)));
                  DY0 : constant Natural := Natural (Float'Rounding (Float'Max (0.0, G.Y)));
               begin
                  if GW > 0 and then GH > 0
                    and then SX0 < AW and then SY0 < AH
                    and then DX0 < W0 and then DY0 < H0
                  then
                     declare
                        Safe_W : constant Natural :=
                          Natural'Min (GW, Natural'Min (AW - SX0, W0 - DX0));
                        Safe_H : constant Natural :=
                          Natural'Min (GH, Natural'Min (AH - SY0, H0 - DY0));
                     begin
                        if Safe_W > 0 and then Safe_H > 0 then
                           for Y in 0 .. Safe_H - 1 loop
                              for X in 0 .. Safe_W - 1 loop
                                 declare
                                    SX : constant Natural := SX0 + X;
                                    SY : constant Natural := SY0 + Y;
                                    DX : constant Natural := DX0 + X;
                                    DY : constant Natural := DY0 + Y;
                                    A_Idx : constant Natural := SY * AW + SX + 1;
                                 begin
                                    if A_Idx <= Result.Atlas_Bytes then
                                       declare
                                          Alpha : constant Interfaces.Unsigned_8 :=
                                            Atlas.all (A_Idx);
                                          P : constant Positive :=
                                            Positive ((DY * W0 + DX) * 4 + 1);
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
                        end if;
                     end;
                  end if;
               end;
            end loop;

            if not Inked then
               return (Width => 0, Height => 0, Pixels => Files.Shared_Bytes.Empty);
            end if;

            --  Crop to the inked bounds so no transparent margin remains on any side.
            declare
               CW : constant Natural := Max_C - Min_C + 1;
               CH : constant Natural := Max_R - Min_R + 1;
            begin
               return Out_Label : Label do
                  Out_Label.Width  := CW;
                  Out_Label.Height := CH;
                  declare
                     Cropped : Byte_Vectors.Vector :=
                       Byte_Vectors.To_Vector (0, Ada.Containers.Count_Type (CW * CH * 4));
                  begin
                     for Row in 0 .. CH - 1 loop
                        for Col in 0 .. CW - 1 loop
                           declare
                              Src : constant Positive :=
                                Positive (((Row + Min_R) * W0 + (Col + Min_C)) * 4 + 1);
                              Dst : constant Positive := Positive ((Row * CW + Col) * 4 + 1);
                           begin
                              Cropped.Replace_Element (Dst, Buf.Element (Src));
                              Cropped.Replace_Element (Dst + 1, Buf.Element (Src + 1));
                              Cropped.Replace_Element (Dst + 2, Buf.Element (Src + 2));
                              Cropped.Replace_Element (Dst + 3, Buf.Element (Src + 3));
                           end;
                        end loop;
                     end loop;
                     Out_Label.Pixels := Files.Shared_Bytes.To_Shared (Cropped);
                  end;
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
      Key : constant String := Theme_Tag (Theme) & ":" & Natural'Image (Height) & ":" & Ext;
   begin
      if Ext = "" or else Height < 1 then
         return (Width => 0, Height => 0, Pixels => Files.Shared_Bytes.Empty);
      end if;
      --  The renderer is (re)loaded only for a label not cached yet.
      if not Cache.Contains (Key) then
         Ensure_Renderer (Height);
         if not Guikit.Text.Loaded (R) then
            return (Width => 0, Height => 0, Pixels => Files.Shared_Bytes.Empty);
         end if;
         if Natural (Cache.Length) >= Max_Cached_Labels then
            Cache.Clear;
         end if;
         declare
            Made : Label;
         begin
            begin
               Made := Rasterize (Ext, Height, Theme);
            exception
               when others =>
                  --  Kept as an empty label: one that cannot be drawn is not
                  --  tried again on every frame.
                  Made := (Width => 0, Height => 0, Pixels => Files.Shared_Bytes.Empty);
            end;
            Cache.Insert (Key, Made);
         end;
      end if;
      return Cache.Element (Key);
   exception
      when others =>
         return (Width => 0, Height => 0,
                 Pixels => Files.Shared_Bytes.Empty);
   end Label_For;

end Files.Extension_Labels;
