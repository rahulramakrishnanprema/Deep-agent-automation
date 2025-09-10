// AEP-5: Basic User Dashboard UI

// Function to fetch user profile data from API
const fetchUserProfile = async () => {
  try {
    const response = await fetch('https://api.example.com/user/profile');
    if (!response.ok) {
      throw new Error('Failed to fetch user profile');
    }
    const data = await response.json();
    return data;
  } catch (error) {
    console.error(error);
  }
};

// Function to render user dashboard with profile details
const renderUserDashboard = async () => {
  const userProfile = await fetchUserProfile();
  if (userProfile) {
    const dashboardElement = document.getElementById('user-dashboard');
    dashboardElement.innerHTML = `
      <div>
        <h2>${userProfile.name}</h2>
        <p>Email: ${userProfile.email}</p>
        <p>Role: ${userProfile.role}</p>
      </div>
    `;
  }
};

// Event listener to load user dashboard on page load
document.addEventListener('DOMContentLoaded', renderUserDashboard);