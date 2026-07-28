separate (Files.Rendering.Build_Frame_Commands)
   function Time_Text
     (Available : Boolean;
      Value     : Ada.Calendar.Time;
      Label_Key : String)
      return UString
   is
   begin
      if not Available then
         return Missing_Info (Label_Key);
      end if;

      return
        Info_Value
          (Label_Key,
           Humanized_Time_Text (Value));
   end Time_Text;
