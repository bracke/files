separate (Files.Rendering.Layouts)
   function View_Mode_Segments return Guikit.Segmented.Segment_Vectors.Vector is
      Result : Guikit.Segmented.Segment_Vectors.Vector;

      procedure Add (Key : String) is
      begin
         Result.Append
           (Guikit.Segmented.Segment'
              (Label   => Ada.Strings.Unbounded.To_Unbounded_String (Files.Localization.Text (Key)),
               others  => <>));
      end Add;
   begin
      Add ("command.view.small.short");
      Add ("command.view.large.short");
      Add ("command.view.details.short");
      return Result;
   end View_Mode_Segments;
