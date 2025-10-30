import './App.css'
import { HashRouter as Router, Routes, Route} from 'react-router-dom'
import { Home } from './pages/home'
import { Signin } from './pages/signin'
import { Signup } from './pages/signup'

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={ <Home/> }/>
        <Route path="/signin" element={ <Signin/> }/>
        <Route path="/signup" element={ <Signup/> }/>
      </Routes>
    </Router>
  )
}

export default App
