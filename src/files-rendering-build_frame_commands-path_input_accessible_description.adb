separate (Files.Rendering.Build_Frame_Commands)
   function Path_Input_Accessible_Description return UString is
   begin
      if Snapshot.Path_Input_Valid or else Length (Snapshot.Path_Input_Error_Key) = 0 then
         return Snapshot.Path_Input_Text;
      end if;

      return
        Snapshot.Path_Input_Text
        & To_Unbounded_String (" ")
        & Localized (To_String (Snapshot.Path_Input_Error_Key));
   end Path_Input_Accessible_Description;
