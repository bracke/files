with Files.IO.Fs_Primitives;
with Files.Diagnostics;
with Ada.Strings.Unbounded;

with Hostkit.Fs;
with Files.Leaf_Names;
with Files.File_System.Support;
with Files.File_System.Recovery;
with Files.File_System.Trash;
with Files.File_Identities;
with Files.Name_Parts;

package body Files.File_System.Recovery_Registry is

   use Ada.Strings.Unbounded;

   function Is_Recovery_Payload (Path : String) return Boolean
     renames Recovery.Recognizes;

   function Release_Recovery_Payload (Path : String) return Mutation_Result
     is separate;

   function Registered_Recovery_Payloads return Files.Types.String_Vectors.Vector
     renames Recovery.Registered_Payloads;

   procedure Sweep_Recovery_Registry
     renames Recovery.Sweep_Registry;

   function Preserve_For_Replace
     (Path : String; Recovery_Path : out Files.Types.UString) return Mutation_Result
     is separate;

end Files.File_System.Recovery_Registry;
