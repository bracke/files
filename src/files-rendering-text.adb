with Ada.Strings.Unbounded;

with Files.Fonts;
with Files.Timing;
with Guikit.Text;

package body Files.Rendering.Text is

   use Ada.Strings.Unbounded;
   use type Text_Render_Status;
   use type Guikit.Draw.Text_Command_Vectors.Vector;

   --  Text rendering is provided by the guikit toolkit. One renderer (fonts
   --  and atlas) per text configuration, shared by the windows that use it:
   --  windows at different zoom levels each keep theirs, instead of loading
   --  the fonts again every time the other one draws. The least recently
   --  used is reloaded when a fifth configuration is needed.
   Max_Pooled_Renderers : constant := 4;
   type Pooled_Renderer is limited record
      Key  : UString;
      Used : Natural := 0;
      R    : Guikit.Text.Renderer;
   end record;
   Pool       : array (1 .. Max_Pooled_Renderers) of Pooled_Renderer;
   Pool_Clock : Natural := 0;
   --  The key of the pooled renderer whose fonts Guikit.Bidi's caret layout
   --  answers for (Guikit.Text.Record_Drawable_Forms): coverage is process
   --  wide, so switching to another pooled renderer records its fonts again.
   Coverage_Key : UString;

   --  Mark Slot as used now: every use advances the clock, so of two windows
   --  drawing between loads the one that drew last is the more recent. On
   --  the (distant) wrap every stamp starts over.
   procedure Touch (Slot : Positive) is
   begin
      if Pool_Clock = Natural'Last then
         for Item of Pool loop
            Item.Used := 0;
         end loop;
         Pool_Clock := 0;
      end if;
      Pool_Clock := Pool_Clock + 1;
      Pool (Slot).Used := Pool_Clock;
   end Touch;

   function Initialize_Text
     (Renderer     : in out Text_Renderer;
      Font_Path    : String;
      Pixel_Size   : Positive;
      Cell_Width   : Positive;
      Cell_Height  : Positive;
      Atlas_Width  : Positive := 1024;
      Atlas_Height : Positive := 1024)
      return Text_Render_Status
   is
      Fallbacks : Guikit.Text.Font_Path_Vectors.Vector;
      Status    : Text_Render_Status;
      Key       : constant UString :=
        To_Unbounded_String
          (Font_Path & Positive'Image (Pixel_Size) & Positive'Image (Cell_Width) & Positive'Image (Cell_Height)
           & Positive'Image (Atlas_Width) & Positive'Image (Atlas_Height));
      Slot      : Positive := 1;
   begin
      --  The configuration asked for, whether or not it loads; a failed load
      --  clears Font_Path below.
      Renderer.Pixel_Size   := Pixel_Size;
      Renderer.Key          := Key;
      Renderer.Font_Path    := To_Unbounded_String (Font_Path);
      Renderer.Cell_Width   := Cell_Width;
      Renderer.Cell_Height  := Cell_Height;
      Renderer.Atlas_Width  := Atlas_Width;
      Renderer.Atlas_Height := Atlas_Height;
      --  Already loaded for this configuration: nothing to load.
      for Index in Pool'Range loop
         if Pool (Index).Key = Key then
            Touch (Index);
            if Coverage_Key /= Key then
               Guikit.Text.Record_Drawable_Forms (Pool (Index).R);
               Coverage_Key := Key;
            end if;
            Renderer.Slot := Index;
            Renderer.Loaded := True;
            return Guikit.Draw.Text_Render_Success;
         end if;
      end loop;
      for Index in Pool'Range loop
         if Pool (Index).Used < Pool (Slot).Used then
            Slot := Index;
         end if;
      end loop;
      Pool (Slot).Key := Null_Unbounded_String;
      Touch (Slot);
      Renderer.Slot := Slot;

      --  Delegate to the guikit text layer; the app owns the font paths.
      for Path of Files.Fonts.Fallback_Font_Paths loop
         Fallbacks.Append (To_String (Path));
      end loop;
      Status :=
        Guikit.Text.Initialize
          (R              => Pool (Slot).R,
           Font_Path      => Font_Path,
           Fallback_Paths => Fallbacks,
           Pixel_Size     => Pixel_Size,
           Cell_Width     => Cell_Width,
           Cell_Height    => Cell_Height,
           Atlas_Width    => Atlas_Width,
           Atlas_Height   => Atlas_Height);
      Renderer.Loaded       := Status = Guikit.Draw.Text_Render_Success;

      --  With this installed the emoji font in the fallback chain can be drawn
      --  in colour; without it those codepoints fall back as they always did.
      if Renderer.Loaded then
         Pool (Slot).Key := Key;
         --  Initialize recorded these fonts' coverage.
         Coverage_Key := Key;
         Guikit.Text.Set_Image_Decoder
           (Pool (Slot).R,
            Files.Fonts.Colour_Glyph_Image_Extent'Access,
            Files.Fonts.Decode_Colour_Glyph_Image'Access);
      end if;

      if not Renderer.Loaded then
         Renderer.Font_Path := Null_Unbounded_String;
      end if;
      return Status;
   end Initialize_Text;

   function Text_Loaded (Renderer : Text_Renderer) return Boolean is (Renderer.Loaded);

   function Text_Glyphs_Current (Renderer : Text_Renderer; Glyphs : Text_Render_Result) return Boolean is
     (Renderer.Loaded
      and then Renderer.Slot in Pool'Range
      and then Pool (Renderer.Slot).Key = Renderer.Key
      and then Guikit.Text.Atlas_Version (Pool (Renderer.Slot).R) = Glyphs.Atlas_Version);

   function Build_Text_Glyphs
     (Renderer : in out Text_Renderer;
      Frame    : Frame_Commands)
      return Text_Render_Result
   is
      Empty : Text_Render_Result;
   begin
      if not Renderer.Loaded then
         return Empty;
      end if;
      --  Its pooled renderer went to another configuration meanwhile.
      if Renderer.Slot not in Pool'Range or else Pool (Renderer.Slot).Key /= Renderer.Key then
         declare
            Status : constant Text_Render_Status :=
              Initialize_Text
                (Renderer, To_String (Renderer.Font_Path), Renderer.Pixel_Size, Renderer.Cell_Width,
                 Renderer.Cell_Height, Renderer.Atlas_Width, Renderer.Atlas_Height);
         begin
            if Status /= Guikit.Draw.Text_Render_Success then
               return Empty;
            end if;
         end;
      end if;
      Touch (Renderer.Slot);
      return Guikit.Text.Build_Glyphs (Pool (Renderer.Slot).R, Frame.Text, Frame.Overlay_Text);
   end Build_Text_Glyphs;

   function Retry_Due
     (Text       : Window_Text;
      Pixel_Size : Positive;
      Now        : Ada.Real_Time.Time)
      return Boolean is
     (not Text.Ready
      and then (Text.Failed_Size /= Pixel_Size or else Files.Timing.Elapsed (Now, Text.Failed_At, Retry_Interval)));

   procedure Note_Failure (Text : in out Window_Text; Pixel_Size : Positive; Now : Ada.Real_Time.Time) is
   begin
      Text.Ready := False;
      Text.Glyphs_Valid := False;
      Text.Failed_Size := Pixel_Size;
      Text.Failed_At := Now;
   end Note_Failure;

   procedure Ensure_Loaded
     (Text       : in out Window_Text;
      Font_Path  : String;
      Pixel_Size : Positive;
      Now        : Ada.Real_Time.Time) is
   begin
      if Retry_Due (Text, Pixel_Size, Now) then
         Text.Glyphs_Valid := False;
         if Initialize_Text (Text.Renderer, Font_Path, Pixel_Size) = Guikit.Draw.Text_Render_Success then
            Text.Ready := True;
            Text.Failed_Size := 0;
         else
            Note_Failure (Text, Pixel_Size, Now);
         end if;
      end if;
   end Ensure_Loaded;

   procedure Invalidate (Text : in out Window_Text) is
   begin
      Text.Ready := False;
      Text.Glyphs_Valid := False;
   end Invalidate;

   function Glyphs_For
     (Text  : in out Window_Text;
      Frame : Frame_Commands;
      Now   : Ada.Real_Time.Time)
      return Text_Render_Result
   is
      None : Text_Render_Result;
   begin
      if not Text.Ready then
         return None;
      elsif Text.Glyphs_Valid
        and then Text.Glyph_Text = Frame.Text
        and then Text.Glyph_Overlay_Text = Frame.Overlay_Text
        and then Text.Glyphs.Status = Guikit.Draw.Text_Render_Success
        and then Text_Glyphs_Current (Text.Renderer, Text.Glyphs)
      then
         return Text.Glyphs;
      end if;
      Text.Glyphs := Build_Text_Glyphs (Text.Renderer, Frame);
      Text.Glyph_Text := Frame.Text;
      Text.Glyph_Overlay_Text := Frame.Overlay_Text;
      Text.Glyphs_Valid := True;
      if not Text_Loaded (Text.Renderer) then
         Note_Failure (Text, Text.Renderer.Pixel_Size, Now);
      end if;
      return Text.Glyphs;
   end Glyphs_For;

end Files.Rendering.Text;
