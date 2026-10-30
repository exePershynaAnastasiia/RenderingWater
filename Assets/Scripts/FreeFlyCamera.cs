
using UnityEngine;
using UnityEngine.InputSystem;

public class FreeFlyCamera : MonoBehaviour
{
    [Header("Movement")]
    public float moveSpeed = 10f;
    public float sprintMultiplier = 3f;

    [Header("Mouse Look")]
    public float mouseSensitivity = 0.1f;

    private float rotationX;
    private float rotationY;

    private void Start()
    {
        rotationX = transform.eulerAngles.x;
        rotationY = transform.eulerAngles.y;
    }

    private void Update()
    {
        Keyboard keyboard = Keyboard.current;
        Mouse mouse = Mouse.current;

        if (keyboard == null || mouse == null)
            return;

        // Hold right mouse button to look around
        if (mouse.rightButton.isPressed)
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;

            Vector2 mouseDelta = mouse.delta.ReadValue();

            rotationY += mouseDelta.x * mouseSensitivity;
            rotationX -= mouseDelta.y * mouseSensitivity;
            rotationX = Mathf.Clamp(rotationX, -89f, 89f);

            transform.rotation = Quaternion.Euler(
                rotationX,
                rotationY,
                0f
            );
        }
        else
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }

        // Calculate movement direction
        Vector3 direction = Vector3.zero;

        if (keyboard.wKey.isPressed)
            direction += transform.forward;

        if (keyboard.sKey.isPressed)
            direction -= transform.forward;

        if (keyboard.aKey.isPressed)
            direction -= transform.right;

        if (keyboard.dKey.isPressed)
            direction += transform.right;

        // Vertical movement
        if (keyboard.eKey.isPressed)
            direction += Vector3.up;

        if (keyboard.qKey.isPressed)
            direction -= Vector3.up;

        // Sprint
        float speed = moveSpeed;

        if (keyboard.leftShiftKey.isPressed)
            speed *= sprintMultiplier;

        transform.position +=
            direction.normalized * speed * Time.deltaTime;
    }

    private void OnDisable()
    {
        Cursor.lockState = CursorLockMode.None;
        Cursor.visible = true;
    }
}
