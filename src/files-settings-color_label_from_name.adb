with Files.Preference_Types;
separate (Files.Settings)
   function Color_Label_From_Name
     (Text  : String;
      Label : out Files.Preference_Types.Color_Label)
      return Boolean
   is
      Lower : constant String := Files.Types.To_Lower_Ascii (Text);
   begin
      if Lower = "red" then
         Label := Files.Preference_Types.Red;
      elsif Lower = "orange" then
         Label := Files.Preference_Types.Orange;
      elsif Lower = "yellow" then
         Label := Files.Preference_Types.Yellow;
      elsif Lower = "green" then
         Label := Files.Preference_Types.Green;
      elsif Lower = "blue" then
         Label := Files.Preference_Types.Blue;
      elsif Lower = "purple" then
         Label := Files.Preference_Types.Purple;
      elsif Lower = "gray" or else Lower = "grey" then
         Label := Files.Preference_Types.Gray;
      else
         Label := Files.Preference_Types.No_Label;
         return False;
      end if;
      return True;
   end Color_Label_From_Name;
