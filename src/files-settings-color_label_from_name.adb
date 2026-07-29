separate (Files.Settings)
   function Color_Label_From_Name
     (Text  : String;
      Label : out Files.Types.Color_Label)
      return Boolean
   is
      Lower : constant String := Files.Types.To_Lower (Text);
   begin
      if Lower = "red" then
         Label := Files.Types.Red;
      elsif Lower = "orange" then
         Label := Files.Types.Orange;
      elsif Lower = "yellow" then
         Label := Files.Types.Yellow;
      elsif Lower = "green" then
         Label := Files.Types.Green;
      elsif Lower = "blue" then
         Label := Files.Types.Blue;
      elsif Lower = "purple" then
         Label := Files.Types.Purple;
      elsif Lower = "gray" or else Lower = "grey" then
         Label := Files.Types.Gray;
      else
         Label := Files.Types.No_Label;
         return False;
      end if;
      return True;
   end Color_Label_From_Name;
