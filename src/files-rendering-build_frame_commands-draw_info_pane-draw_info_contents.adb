separate (Files.Rendering.Build_Frame_Commands.Draw_Info_Pane)
   --  The pane's sections: the empty-selection note, or the coalesced
   --  multi-item layout, or the single item's fields.
   procedure Draw_Info_Contents is
      --  The combined selection total is rendered as the last line of the
      --  Contents section (see Coalesced_Info_Sections), so no header rows
      --  are reserved above the list: sections start at the top of the pane.
      Row_Y  : constant Integer :=
        Integer (Guikit.Layout.Saturating_Add (Info_Pane.Y, Info_Pane_Padding (Line_Height)))
        - Integer (Info_Pane.Scroll_Pixels);
      Text_X : constant Natural := Guikit.Layout.Saturating_Add (Info_Pane.X, Info_Pane_Padding (Line_Height));
      Info_Bottom : constant Natural := Guikit.Layout.Saturating_Add (Info_Pane.Y, Info_Pane.Height);
      --  The width the layout counted rows at, which always leaves the
      --  scrollbar's column: wrapping wider when it is hidden drew fewer
      --  rows than the pane was sized for.
      Text_W : constant Natural :=
        Info_Text_Width (Layout, Scrollbar_W => Natural'Min (Scrollbar_Width (Layout), Layout.Info_Pane_Width));

      --  What a screen reader hears for an item, in the locale's words
      --  and punctuation: its type and size, then (in the single-item
      --  layout) when it was modified and any metadata error.
      function Info_Description (Info : Info_Snapshot; Full : Boolean) return String is
         function Arg (Name, Value : String) return Files.Localization.Argument is
           ((To_Unbounded_String (Name), To_Unbounded_String (Value)));
         Summary : constant String :=
           Files.Localization.Text
             ("accessibility.info.summary",
              Files.Localization.Argument_List'
              [Arg ("type_label", Files.Localization.Text ("info.filetype")),
               Arg ("type", To_String (Info_Field_Value (Info, Info_Filetype))),
               Arg ("size_label", Files.Localization.Text ("info.size")),
               Arg ("size", To_String (Info_Field_Value (Info, Info_Size)))]);
         Modified : constant String :=
           (if Full
            then Files.Localization.Text
              ("accessibility.info.summary_modified",
               Files.Localization.Argument_List'
               [Arg ("summary", Summary),
                Arg ("modified",
                     To_String (Time_Text (Info.Modified_Available, Info.Modified_Time, "info.modified")))])
            else Summary);
      begin
         if not Full or else not Info.Metadata_Error then
            return Modified;
         end if;
         return Files.Localization.Text
           ("accessibility.info.metadata_error",
            Files.Localization.Argument_List'
            [Arg ("summary", Modified),
             Arg ("error_label", Files.Localization.Text ("info.metadata_error")),
             Arg ("error", Files.Localization.Text (To_String (Info.Error_Key)))]);
      end Info_Description;

      --  Text helpers shared by the multi-item and the single-item layout.
      procedure Add_Info_Text
        (Offset : Natural;
         Text   : UString;
         Color  : Render_Color := Text_Color;
         Fit    : Boolean := True)
      is
         Y : constant Integer :=
           Saturating_Integer_Add (Row_Y, Saturating_Multiply (Offset, Line_Height));
      begin
         if Y >= Integer (Info_Pane.Y)
           and then Y < Integer (Info_Bottom)
         then
            Add_Text
              (Text_X,
               Natural (Y),
               Text_W,
               Natural'Min (Line_Height, Info_Bottom - Natural (Y)),
               Text,
               Color,
               Fit => Fit);
         end if;
      end Add_Info_Text;

      procedure Add_Info_Label
        (Row : Natural;
         Key : String)
      is
         Text : constant UString := To_Unbounded_String (Files.Localization.Text (Key));
      begin
         Add_Info_Text (Row, Text, Text_Color);
         if Text_W > 1 then
            declare
               Y : constant Integer :=
                 Saturating_Integer_Add (Row_Y, Saturating_Multiply (Row, Line_Height));
            begin
               if Y >= Integer (Info_Pane.Y)
                 and then Y < Integer (Info_Bottom)
               then
                  Add_Text
                    (Guikit.Layout.Saturating_Add (Text_X, 1),
                     Natural (Y),
                     Text_W - 1,
                     Natural'Min (Line_Height, Info_Bottom - Natural (Y)),
                     Text,
                     Text_Color,
                     Fit => True);
               end if;
            end;
         end if;

         --  A "<key>.tooltip" catalog entry, when present, describes
         --  the section on hover.
         declare
            Tip_Key : constant String := Key & ".tooltip";
            Tip_Y   : constant Integer :=
              Saturating_Integer_Add (Row_Y, Saturating_Multiply (Row, Line_Height));
         begin
            if Text_W > 0
              and then Tip_Y >= Integer (Info_Pane.Y)
              and then Tip_Y < Integer (Info_Bottom)
              and then Files.Localization.Text (Tip_Key) /= Tip_Key
            then
               Add_Tooltip
                 (Text_X,
                  Natural (Tip_Y),
                  Text_W,
                  Natural'Min (Line_Height, Info_Bottom - Natural (Tip_Y)),
                  Tip_Key);
            end if;
         end;
      end Add_Info_Label;

      procedure Add_Info_Wrapped_Value
        (Row   : Natural;
         Text  : UString;
         Color : Render_Color := Text_Color)
      is
         Raw : constant String := To_String (Text);

         procedure Add_Line (Line : Natural; First : Integer; Last : Integer) is
         begin
            if Last >= First then
               Add_Info_Text
                 (Guikit.Layout.Saturating_Add (Row, Line),
                  To_Unbounded_String (Raw (First .. Last)),
                  Color,
                  Fit => False);
            end if;
         end Add_Line;
      begin
         For_Each_Wrapped_Line (Raw, Text_W, Line_Height, Add_Line'Access);
      end Add_Info_Wrapped_Value;

      --  Field-major coalesced sections for two or more selected items.
      procedure Draw_Multi_Item_Info is separate;

      --  The single selected item's heading and fields.
      procedure Draw_Single_Item_Info (Info : Info_Snapshot) is separate;
   begin
      if Snapshot.Selected_Info.Is_Empty then
         declare
            Text_Y : constant Natural :=
              Guikit.Layout.Saturating_Add (Info_Pane.Y, Info_Pane_Padding (Line_Height));
         begin
            if Text_Y < Info_Bottom then
               Add_Text
                 (Guikit.Layout.Saturating_Add (Info_Pane.X, Info_Pane_Padding (Line_Height)),
                  Text_Y,
                  Info_Text_Width (Layout, Scrollbar_W => 0),
                  Natural'Min (Line_Height, Info_Bottom - Text_Y),
                  Localized ("error.selection.empty"),
                  Muted_Text_Color,
                  Fit => True);
            end if;
         end;
      end if;

      if Natural (Snapshot.Selected_Info.Length) >= 2 then
         Draw_Multi_Item_Info;
      else
         for Index in 1 .. Natural (Snapshot.Selected_Info.Length) loop
            Draw_Single_Item_Info (Snapshot.Selected_Info.Element (Positive (Index)));
         end loop;
      end if;
   end Draw_Info_Contents;
