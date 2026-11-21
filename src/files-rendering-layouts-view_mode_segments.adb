separate (Files.Rendering.Layouts)
   function View_Mode_Segments return Guikit.Segmented.Segment_Vectors.Vector is
      Result : Guikit.Segmented.Segment_Vectors.Vector;

      --  Each cell's short label, in View_Mode order (View_Mode_Cell).
      function Short_Key (Mode : Files.Preference_Types.View_Mode) return String is
        (case Mode is
            when Files.Preference_Types.Small_Icons => "command.view.small.short",
            when Files.Preference_Types.Large_Icons => "command.view.large.short",
            when Files.Preference_Types.Details     => "command.view.details.short");
   begin
      for Mode in Files.Preference_Types.View_Mode loop
         Result.Append
           (Guikit.Segmented.Segment'
              (Label   => Ada.Strings.Unbounded.To_Unbounded_String (Files.Localization.Text (Short_Key (Mode))),
               others  => <>));
      end loop;
      return Result;
   end View_Mode_Segments;
