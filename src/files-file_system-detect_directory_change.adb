separate (Files.File_System)
   function Detect_Directory_Change
     (Before_State : Directory_Signature;
      Path         : String)
      return Directory_Change_Result
   is
      After_State : constant Directory_Signature := Directory_State (Path);
      Changed     : constant Boolean :=
        Before_State.Exists /= After_State.Exists
        or else Before_State.Entry_Count /= After_State.Entry_Count
        or else Before_State.Entry_State_Checksum /= After_State.Entry_State_Checksum
        or else Before_State.Latest_Modified_Known /= After_State.Latest_Modified_Known
        or else
          (Before_State.Latest_Modified_Known
           and then After_State.Latest_Modified_Known
           and then Before_State.Latest_Modified /= After_State.Latest_Modified);
   begin
      return
        (Changed      => Changed,
         Before_State => Before_State,
         After_State  => After_State,
         Error_Key    =>
           (if After_State.Exists then Null_Unbounded_String else To_Unbounded_String ("error.directory.load")));
   end Detect_Directory_Change;
