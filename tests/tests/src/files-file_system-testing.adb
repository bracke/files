with Ada.Strings.Unbounded;

package body Files.File_System.Testing is
   use Ada.Strings.Unbounded;

   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request
   is
      Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   begin
      return
        (Backend                 => Backend,
         Path                    => To_Unbounded_String (Path),
         Requires_Native_Api     => Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native,
         Can_Use_Current_Process => Backend not in Trash_Windows_Recycle_Bin | Trash_Macos_Native);
   end Native_Trash_Request_For;

   function Execute_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
   is
      Evaluation : constant Native_Trash_Result := Evaluate_Native_Trash (Request);
      Mutation   : Mutation_Result;
   begin
      if Request.Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native then
         return Trash_Natively (Request);
      end if;

      if not Evaluation.Supported then
         return
           (Supported             => False,
            Attempted             => False,
            Completed             => False,
            Native_Binding_Available => Evaluation.Native_Binding_Available,
            Native_Binding_Status => Evaluation.Native_Binding_Status,
            Binding_Unit          => Evaluation.Binding_Unit,
            Desktop_Standard      => Evaluation.Desktop_Standard,
            Would_Delete          => Evaluation.Would_Delete,
            Uses_Recycle_Bin      => Evaluation.Uses_Recycle_Bin,
            Adapter_Name          => Evaluation.Adapter_Name,
            Native_Api_Name       => Evaluation.Native_Api_Name,
            Operation_Name        => Evaluation.Operation_Name,
            Requires_User_Consent => Evaluation.Requires_User_Consent,
            Preserves_Metadata    => Evaluation.Preserves_Metadata,
            Error_Key             => Evaluation.Error_Key);
      end if;

      Mutation := Move_To_Trash (To_String (Request.Path));
      return
        (Supported             => True,
         Attempted             => True,
         Completed             => Mutation.Success,
         Native_Binding_Available => Evaluation.Native_Binding_Available,
         Native_Binding_Status => Evaluation.Native_Binding_Status,
         Binding_Unit          => Evaluation.Binding_Unit,
         Desktop_Standard      => Evaluation.Desktop_Standard,
         Would_Delete          => False,
         Uses_Recycle_Bin      => Evaluation.Uses_Recycle_Bin,
         Adapter_Name          => Evaluation.Adapter_Name,
         Native_Api_Name       => Evaluation.Native_Api_Name,
         Operation_Name        => Evaluation.Operation_Name,
         Requires_User_Consent => Evaluation.Requires_User_Consent,
         Preserves_Metadata    => Evaluation.Preserves_Metadata,
         Error_Key             => Mutation.Error_Key);
   end Execute_Native_Trash;

end Files.File_System.Testing;
