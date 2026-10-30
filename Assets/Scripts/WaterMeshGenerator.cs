
using UnityEngine;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class WaterMeshGenerator : MonoBehaviour
{
    [Header("Mesh Settings")]
    [Min(1)] public int resolution = 100;
    [Min(0.1f)] public float size = 10f;

    private void Start()
    {
        GenerateMesh();
    }

    private void GenerateMesh()
    {
        Mesh mesh = new Mesh();
        mesh.name = "Water Mesh";

        int vertexCount = (resolution + 1) * (resolution + 1);

        Vector3[] vertices = new Vector3[vertexCount];
        Vector2[] uvs = new Vector2[vertexCount];
        int[] triangles = new int[resolution * resolution * 6];

        // Generate vertices and UV coordinates
        for (int z = 0; z <= resolution; z++)
        {
            for (int x = 0; x <= resolution; x++)
            {
                int index = z * (resolution + 1) + x;

                float xPos = (float)x / resolution;
                float zPos = (float)z / resolution;

                vertices[index] = new Vector3(
                    (xPos - 0.5f) * size,
                    0f,
                    (zPos - 0.5f) * size
                );

                uvs[index] = new Vector2(xPos, zPos);
            }
        }

        // Generate triangles
        int triangleIndex = 0;

        for (int z = 0; z < resolution; z++)
        {
            for (int x = 0; x < resolution; x++)
            {
                int start = z * (resolution + 1) + x;

                triangles[triangleIndex++] = start;
                triangles[triangleIndex++] = start + resolution + 1;
                triangles[triangleIndex++] = start + 1;

                triangles[triangleIndex++] = start + 1;
                triangles[triangleIndex++] = start + resolution + 1;
                triangles[triangleIndex++] = start + resolution + 2;
            }
        }

        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.triangles = triangles;

        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        GetComponent<MeshFilter>().mesh = mesh;
    }
}
