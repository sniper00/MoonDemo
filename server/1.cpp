#include <vector>
#include <algorithm>
#include <iostream>

using namespace std;

class Solution {
public:
    void nextPermutation(vector<int>& nums) {
        if(nums.size()<=1){
            return;
        }
        auto n = nums.size();
        auto i = n - 2;
        auto j = n - 1;
        auto k = n - 1;

        for(;i>=0 && nums[i]>=nums[j];){
            --i;
            --j;
        }

        if(i>=0){
            while(nums[i]>=nums[k]){
                k--;
            }
            std::swap(nums[i], nums[k]);
        }

        auto x = j;
        auto y = nums.size() - 1;
        for(;x<y; x++, y--){
            std::swap(nums[x], nums[y]);¬
        }
    }
};

int main() {
    vector<int> nums = {3, 2, 1};
    Solution s;
    s.nextPermutation(nums);
    for(auto i : nums){
        cout << i << " ";
    }
    cout << endl;
    return 0;
}