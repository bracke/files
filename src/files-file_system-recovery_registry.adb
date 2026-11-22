package body Files.File_System.Recovery_Registry is

   function Is_Recovery_Payload (Path : String) return Boolean
     renames Files.File_System.Is_Recovery_Payload;

   function Release_Recovery_Payload (Path : String) return Mutation_Result
     renames Files.File_System.Release_Recovery_Payload;

   function Registered_Recovery_Payloads return Files.Types.String_Vectors.Vector
     renames Files.File_System.Registered_Recovery_Payloads;

   procedure Sweep_Recovery_Registry
     renames Files.File_System.Sweep_Recovery_Registry;

   function Preserve_For_Replace
     (Path : String; Recovery_Path : out Files.Types.UString) return Mutation_Result
     renames Files.File_System.Preserve_For_Replace;

end Files.File_System.Recovery_Registry;
