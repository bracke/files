separate (Files_Suite.Rendering)
   --  An emoji in a filename draws as a picture, in both layers.
   --
   --  It cannot be a glyph quad: those read the alpha atlas, where a pixel is one
   --  coverage value with nowhere to keep a colour. So it leaves the text layer
   --  as an icon and joins the icon pass. This checks that seam end to end --
   --  decoder installed, font in the chain, picture produced -- because each part
   --  of it lives in a different crate and nothing else in CI renders an emoji.
   --
   --  The overlay layer is the half that had never been exercised: an emoji in a
   --  Quick Look title has to composite above the panel rather than under it.
   --
   --  Skipped where no colour font is installed, which is not a defect in files.
   procedure Test_Emoji_Draws_As_Colour_Icons (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Emoji_Font : constant String :=
        "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf";

      --  U+1F389 PARTY POPPER, spelled out so the file stays plain ASCII.
      Party : constant String :=
        Character'Val (16#F0#) & Character'Val (16#9F#)
        & Character'Val (16#8E#) & Character'Val (16#89#);

      Renderer : Text_Renderer;
      Frame    : Frame_Commands;
      Text     : Guikit.Draw.Text_Render_Result;

      function Line (Content : String) return Guikit.Draw.Text_Command is
         Cmd : Guikit.Draw.Text_Command;
      begin
         Cmd.X := 0;
         Cmd.Y := 0;
         Cmd.Width := 400;
         Cmd.Height := 20;
         Cmd.Text := To_Unbounded_String (Content);
         return Cmd;
      end Line;

      Main_Layer    : Natural := 0;
      Overlay_Layer : Natural := 0;
      Carried_Pictures : Natural := 0;
      Tile_Identity : Unbounded_String;
   begin
      if not Ada.Directories.Exists (Emoji_Font) then
         Files_Suite.Support.Skip ("Test_Emoji_Draws_As_Colour_Icons", "the Noto Color Emoji font is not installed");
         return;
      end if;

      Assert
        (Initialize_Text (Renderer, Files.Fonts.Default_Font_Path, 16, 10, 20)
         = Guikit.Draw.Text_Render_Success,
         "the text renderer initialises");

      Frame.Text.Append (Line ("a " & Party & " b"));
      Frame.Overlay_Text.Append (Line ("c " & Party & " d"));

      Text := Build_Text_Glyphs (Renderer, Frame);

      Assert (Text.Status = Guikit.Draw.Text_Render_Success, "the text builds");
      Files_Suite.Support.Assert_Equal
        (Natural (Text.Colour_Icons.Length),
         2,
         "both emoji become colour icons, got"
         & Natural'Image (Natural (Text.Colour_Icons.Length)));

      for Icon of Text.Colour_Icons loop
         Assert (Icon.Thumbnail_Width > 0 and then Icon.Thumbnail_Height > 0,
                 "the picture has a size");
         Assert (Icon.Shared_Tile_Id /= Null_Unbounded_String,
                 "and names an identity so repeats share one atlas tile");
         if not Icon.Thumbnail_Pixels.Is_Empty then
            Files_Suite.Support.Assert_Equal
              (Icon.Thumbnail_Pixels.Length,
               Icon.Thumbnail_Width * Icon.Thumbnail_Height * 4,
               "the carried picture has four bytes per pixel");
            Carried_Pictures := Carried_Pictures + 1;
            Tile_Identity := Icon.Shared_Tile_Id;
         else
            Assert (Icon.Shared_Tile_Id = Tile_Identity, "a repeated emoji reuses the carried picture's tile");
         end if;

         if Icon.Overlay then
            Overlay_Layer := Overlay_Layer + 1;
         else
            Main_Layer := Main_Layer + 1;
         end if;
      end loop;
      Files_Suite.Support.Assert_Equal
        (Carried_Pictures,
         1,
         "the shared emoji picture is carried once across both layers");

      --  One from each layer: an emoji in an overlay must stay in the overlay,
      --  or it draws underneath the panel it belongs to.
      Assert (Main_Layer = 1 and then Overlay_Layer = 1,
              "one icon per layer, got" & Natural'Image (Main_Layer)
              & " main and" & Natural'Image (Overlay_Layer) & " overlay");

      --  Missing glyphs would mean it fell through to the '?' path instead.
      Files_Suite.Support.Assert_Equal (Text.Missing_Glyph_Count, 0, "and nothing was reported missing");
   end Test_Emoji_Draws_As_Colour_Icons;
